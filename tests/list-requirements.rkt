#lang racket/base

(require rackunit racket/file racket/list racket/port racket/runtime-path racket/system
         "../assessor.rkt" "../workflow-model.rkt" "../private/reader.rkt")

(define-runtime-path example "../examples/list-requirements.rkt")
(define declaration
  (string-append "interface \"Timing-series\" [must [measurements] "
                 "for each measurement in measurements [must [measurement.period measurement.period.u]]]\n"))

(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-list-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"List requirements\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))
(define (run body)
  (with-source body (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))
(define (outcomes body)
  (with-source body (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))
(define (check-record values)
  (outcomes (string-append declaration "series = [measurements = " values "]\nseries implement Timing-series\n")))

(module+ test
  (check-equal? (with-output-to-string (lambda () (dynamic-require example #f))) "")
  (check-equal? (assessment-findings (assess-file example)) '())
  (check-equal? (check-record "[[period = 2 u []] [period = 2.1 u []]]") '(satisfied))
  (check-equal? (check-record "[[period = 2 u []] [period = 2.1]]") '(violated))
  (check-equal? (check-record "[[period = 2 u []] [note = \"not measured\"]]") '(violated))
  (check-equal? (check-record "[]") '(satisfied))
  (check-equal? (check-record "unknown") '(undetermined))
  (check-equal? (check-record "[[period = unknown]]") '(undetermined))
  (check-equal? (check-record "[unknown]") '(undetermined))
  (check-equal? (check-record "[[period = unknown u []]]") '(satisfied))
  (check-equal? (check-record "[2]") '(violated))
  (check-equal? (check-record "\"not a list\"") '(violated))
  (check-equal? (outcomes (string-append declaration "series = []\nseries implement Timing-series\n")) '(violated))
  (check-exn #rx"measurements.\\[2\\].period.u"
             (lambda () (run (string-append declaration
                                            "series = Timing-series.[measurements = [[period = 2 u []] [period = 2.1]]]\n"))))

  ;; Reuse value comparisons, including on scalar items and surrounding entries.
  (define compared
    (string-append "interface \"Counts\" [must [counts minimum] "
                   "for each count in counts [must [count > minimum]]]\n"))
  (check-equal? (outcomes (string-append compared "series = [counts = [11 20] minimum = 10]\nseries implement Counts\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append compared "series = [counts = [11 9] minimum = 10]\nseries implement Counts\n"))
                '(violated))
  (check-equal? (outcomes (string-append compared "series = [counts = [11 unknown] minimum = 10]\nseries implement Counts\n"))
                '(undetermined))
  (check-equal? (outcomes (string-append compared "series = [counts = [unknown 9] minimum = 10]\nseries implement Counts\n"))
                '(violated))
  (check-equal? (run (string-append compared "series = Counts.[counts = [11 20] minimum = 10]\nprint series.counts.[2]\n"))
                "20\n")
  (check-exn #rx"does not satisfy value requirement"
             (lambda () (run (string-append compared "series = Counts.[counts = [11 9] minimum = 10]\n"))))
  (check-exn #rx"undetermined value requirement"
             (lambda () (run (string-append compared "series = Counts.[counts = unknown minimum = 10]\n"))))
  (check-equal? (outcomes (string-append compared "series = [counts = [11 u []] minimum = 10]\nseries implement Counts\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append compared "series = [counts = [unknown u []] minimum = 10]\nseries implement Counts\n"))
                '(undetermined))
  (check-equal? (outcomes (string-append compared "series = [counts = [11 20] u [] minimum = 10]\nseries implement Counts\n"))
                '(satisfied))
  (check-equal? (run (string-append compared
                                   "series = Counts.[counts = [11 20] u [] minimum = 10]\nprint series.counts.u.declared\n"))
                "[]\n")

  ;; The existing conditional syntax can choose per-item requirements.
  (define conditional
    (string-append "interface \"Methods\" [must [measurements] for each m in measurements ["
                   "must [m.method] if m.method == \"automatic\" [must [m.instrument]] "
                   "else if m.method == \"video\" [must [m.frame-rate >= 25]] "
                   "else [must [m.observer]]]]\n"))
  (check-equal? (outcomes (string-append conditional
                                        "series = [measurements = [[method = \"automatic\" instrument = \"timer\"] [method = \"manual\" observer = \"researcher\"]]]\nseries implement Methods\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append conditional
                                        "series = [measurements = [[method = \"video\" frame-rate = 10]]]\nseries implement Methods\n"))
                '(violated))
  (check-equal? (outcomes (string-append conditional
                                        "series = [measurements = [[method = unknown]]]\nseries implement Methods\n"))
                '(undetermined))
  (check-equal? (run (string-append "interface \"Conditional-default\" [must [measurements] "
                                   "for each m in measurements [must [m.method] "
                                   "if m.method == \"automatic\" [must [m.unit = \"seconds\"]]]]\n"
                                   "series = Conditional-default.[measurements = [[method = \"automatic\"] [method = \"manual\"]]]\n"
                                   "print series.measurements.[1].unit\n"))
                "seconds\n")
  (check-equal? (outcomes
                 (string-append "interface \"Optional\" [must [enabled] measurements "
                                "if enabled [for each m in measurements [must [m.period]]]]\n"
                                "series = [enabled = false]\nseries implement Optional\n"))
                '(satisfied))

  ;; Defaults complete the corresponding list items during construction only.
  (define defaulted
    (string-append "interface \"Defaulted\" [must [measurements] for each m in measurements ["
                   "must [m.period m.unit = \"seconds\"]]]\n"))
  (check-equal? (run (string-append defaulted
                                   "series = Defaulted.[measurements = [[period = 2] [period = 3 unit = \"minutes\"]]]\n"
                                   "print series.measurements.[1].unit print series.measurements.[2].unit\n"))
                "seconds\nminutes\n")
  (check-equal? (outcomes (string-append defaulted
                                        "series = [measurements = [[period = 2]]]\nseries implement Defaulted\n"))
                '(violated))
  (check-equal? (run (string-append "interface \"Indexed\" [must [groups] for each m in groups.[1] [must [m.unit = \"seconds\"]]]\n"
                                   "series = Indexed.[groups = [[[period = 2]]]]\nprint series.groups.[1].[1].unit\n"))
                "seconds\n")

  ;; Nested lists retain both item bindings.
  (define nested
    (string-append "interface \"Groups\" [must [groups] for each group in groups [must [group.limit group.values] "
                   "for each value in group.values [must [value > group.limit]]]]\n"))
  (check-equal? (outcomes (string-append nested
                                        "series = [groups = [[limit = 10 values = [11 20]] [limit = 20 values = [21]]]]\nseries implement Groups\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append nested
                                        "series = [groups = [[limit = 10 values = [11 9]]]]\nseries implement Groups\n"))
                '(violated))
  (check-equal? (run (string-append "interface \"Nested-default\" [must [groups] for each g in groups ["
                                   "must [g.measurements] for each m in g.measurements [must [m.unit = \"seconds\"]]]]\n"
                                   "series = Nested-default.[groups = [[measurements = [[period = 2]]]]]\n"
                                   "print series.groups.[1].measurements.[1].unit\n"))
                "seconds\n")
  (check-equal? (outcomes (string-append "interface \"Nested-part\" [must [session [must [measurements] "
                                        "for each m in measurements [must [m.period > 0]]]]]\n"
                                        "series = [session = [measurements = [[period = 2]]]]\nseries implement Nested-part\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append "interface \"Optional-part\" [must [measurements] "
                                        "for each m in measurements [m.details [must [note]]]]\n"
                                        "series = [measurements = [[details = unknown]]]\nseries implement Optional-part\n"))
                '(undetermined))
  (check-equal? (outcomes (string-append "interface \"Range\" [for each n in range 1 to 3 step 1 [must [n > 0]]]\n"
                                        "series = [note = \"plan\"]\nseries implement Range\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append declaration "items = [[period = 2 u []]]\n"
                                        "series = [measurements = items]\nseries implement Timing-series\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append declaration
                                        "series = [measurements = [[period = 2 u []] [period = 2.1 u []]]]\n"
                                        "series.measurements.[2].period = 2.1\nseries implement Timing-series\n"))
                '(violated))
  (check-equal? (outcomes (string-append declaration
                                        "series = [measurements = [[period = 2]]]\n"
                                        "series.measurements.[1].period = 2 u []\nseries implement Timing-series\n"))
                '(satisfied))

  ;; The loop and its body retain their source locations without making the
  ;; item name a workflow-level requirement or an execution activity.
  (with-source
   (string-append declaration "stage \"Measure\"\n\"Measure\" implement Timing-series\n")
   (lambda (file)
     (define method (read-workflow-model file))
     (define interface (mapping-model-interface (first (workflow-model-mappings method))))
     (define iteration
       (findf (lambda (condition) (eq? (condition-model-kind condition) 'collection-requirement))
              (interface-model-conditions interface)))
     (check-equal? (interface-iteration-model-name (condition-model-evidence iteration)) 'measurement)
     (check-equal? (interface-iteration-model-collection (condition-model-evidence iteration)) '(result measurements))
     (define body (interface-iteration-model-body (condition-model-evidence iteration)))
     (check-equal? (map condition-model-target (interface-model-conditions body)) '(measurement.period measurement.period.u))
     (check-true (andmap (lambda (condition) (source-ref? (condition-model-source condition)))
                         (interface-model-conditions body)))
     (check-false (ormap (lambda (activity) (eq? (activity-model-kind activity) 'for-each))
                         (workflow-model-activities method)))
     (check-equal? (map condition-check-outcome (assessment-checks (assess-workflow method))) '(satisfied undetermined))))

  ;; Inheritance preserves the loop once through a diamond; existing imports,
  ;; includes, and standalone interface files preserve the same requirements.
  (with-source
   (string-append declaration "interface \"Left\" [extends Timing-series]\n"
                  "interface \"Right\" [extends Timing-series]\n"
                  "interface \"Combined\" [extends Left extends Right]\n"
                  "series = Combined.[measurements = [[period = 2 u []]]]\nseries implement Combined\n")
   (lambda (file)
     (check-equal? (map condition-check-outcome (assessment-checks (assess-file file))) '(satisfied))))
  (with-source
   (string-append declaration "interface \"Left\" [extends Timing-series]\n"
                  "interface \"Right\" [extends Timing-series]\n"
                  "interface \"Combined\" [extends Left extends Right]\n"
                  "stage \"Measure\"\n\"Measure\" implement Combined\n")
   (lambda (file)
     (define model (read-workflow-model file))
     (define interface (mapping-model-interface (first (workflow-model-mappings model))))
     (check-equal? (count (lambda (condition) (eq? (condition-model-kind condition) 'collection-requirement))
                          (interface-model-conditions interface)) 1)))
  (define directory (make-temporary-file "sciencelogo-list-library-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (display-to-file (string-append "#lang sciencelogo\n" declaration) (build-path directory "series.rkt"))
      (display-to-file (string-append "#lang sciencelogo\nlibrary \"timing\" [" declaration "]\n")
                       (build-path directory "library.rkt"))
      (define (git . args)
        (define code (parameterize ([current-output-port (open-output-string)]
                                    [current-error-port (open-output-string)])
                       (apply system*/exit-code (find-executable-path "git")
                              "-C" (path->string directory) args)))
        (unless (zero? code) (error 'list-library "Git failed: ~a" args)))
      (git "init" "--initial-branch=main")
      (git "add" "library.rkt" "series.rkt")
      (git "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid"
           "commit" "--quiet" "-m" "Add list requirements")
      (git "tag" "v1")
      (define body
        (format (string-append "import ~s at \"v1\" as timing\n"
                               "series = timing.Timing-series.[measurements = [[period = 2 u []]]]\n"
                               "series implement timing.Timing-series\nprint series.measurements.[1].period\n")
                (format "file://~a" directory)))
      (check-equal? (run body) "2\n")
      (check-equal? (outcomes body) '(satisfied))
      (define file (build-path directory "workflow.rkt"))
      (display-to-file
       "#lang sciencelogo\nseries = [measurements = [[period = 2]]]\nseries implement \"series.rkt\"\n" file)
      (check-equal? (map condition-check-outcome (assessment-checks (assess-file file))) '(violated))
      (display-to-file
       "#lang sciencelogo\ninclude \"series.rkt\"\nseries = [measurements = [[period = 2 u []]]]\nseries implement Timing-series\n"
       file #:exists 'truncate)
      (check-equal? (map condition-check-outcome (assessment-checks (assess-file file))) '(satisfied)))
    (lambda () (delete-directory/files directory)))

  (for ([invalid (in-list
                  (list "interface \"Bad\" [must [measurements] for each m in measurements [must [m.period m.period]]]\n"
                        "interface \"Bad\" [must [measurements] for each m.x in measurements [must [m.period]]]\n"
                        "interface \"Bad\" [must [measurements] for each m in measurements [must [period]]]\n"
                        "interface \"Bad\" [must [measurements] for each m in measurements [must [m.period > missing]]]\n"
                        "interface \"Bad\" [must [measurements] for each m in :measurements [must [m.period]]]\n"
                        "interface \"Bad\" [must [measurements] for each m in measurements [version \"1\"]]\n"
                        "interface \"Bad\" [must [measurements] for each m in measurements [extends Other]]\n"))])
    (with-source invalid (lambda (file) (check-exn exn:fail:read? (lambda () (read-workflow-model file)))))))
