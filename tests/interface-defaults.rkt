#lang racket/base

(require rackunit racket/file racket/list racket/port racket/runtime-path racket/system
         "../assessor.rkt" "../workflow-model.rkt")

(define-runtime-path example "../examples/interface-defaults.rkt")
(define timing "interface \"Timing\" [must [period is number unit = \"seconds\" period > 0]]\n")
(define experiment "interface \"Experiment\" [must [timing = unknown Timing]]\n")
(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-interface-default-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"Interface defaults\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))
(define (run body)
  (with-source body (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))
(define (outcomes body)
  (with-source body (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))

(module+ test
  ;; The field is compulsory; construction supplies unknown, while checks do not.
  (check-equal? (run (string-append experiment timing "trial = Experiment.[]\nprint trial.timing\nprint trial is Experiment\n"))
                "unknown\ntrue\n")
  (check-equal? (outcomes (string-append timing experiment "trial = [timing = unknown]\ntrial implement Experiment\n")) '(satisfied))
  (check-equal? (outcomes (string-append timing experiment "trial = [other = 1]\ntrial implement Experiment\n")) '(violated))
  (for ([value (in-list '("[period = 2 unit = \"seconds\"]"
                         "[period = 2 unit = \"minutes\" notes = \"manual\"]"
                         "unknown"))])
    (check-not-exn (lambda () (run (string-append timing experiment "trial = Experiment.[timing = " value "]\n"))))
    (check-equal? (outcomes (string-append timing experiment "trial = [timing = " value "]\ntrial implement Experiment\n")) '(satisfied)))
  (for ([value (in-list '("[period = 2]" "[unit = \"seconds\"]"
                         "[period = -1 unit = \"seconds\"]"
                         "[period = unknown unit = \"seconds\"]"
                         "[period = \"two\" unit = \"seconds\"]"
                         "2" "\"timing\"" "[1 2]" "false"))])
    (check-exn #rx"wrong kind.*timing"
               (lambda () (run (string-append timing experiment "trial = Experiment.[timing = " value "]\n"))))
    (check-equal? (outcomes (string-append timing experiment "trial = [timing = " value "]\ntrial implement Experiment\n")) '(violated)))
  (check-equal? (run (string-append timing experiment "trial = Experiment.[timing = [period = 2 unit = \"seconds\"]]\nprint trial.timing.period\ntrial.timing = 2\nprint trial is Experiment\n")) "2\nfalse\n")
  (check-equal? (outcomes (string-append timing experiment "to measure [output 2]\ndo measure as period\ntrial = [timing = [period = period unit = \"seconds\"]]\ntrial implement Experiment\n")) '(undetermined))
  (check-equal? (outcomes (string-append timing experiment "to measure [output 2]\ndo measure as period\ntrial = [timing = [period = period]]\ntrial implement Experiment\n")) '(violated))
  ;; The permission for the whole field does not waive an additional is test.
  (check-equal? (outcomes (string-append timing "interface \"Checked\" [must [timing = unknown Timing timing is Timing]]\ntrial = [timing = unknown]\ntrial implement Checked\n")) '(undetermined))
  (check-equal? (run (string-append timing "interface \"Qualified\" [must [timing = unknown u [] Timing]]\ntrial = Qualified.[]\nprint trial.timing == unknown\n")) "true\n")

  ;; Adjacent ordinary fields retain their meaning; group boundaries are explicit.
  (check-equal? (run "interface \"Legacy\" [must [period = unknown notes]]\ntrial = Legacy.[notes = \"pending\"]\nprint trial.period\nprint trial.notes\n") "unknown\npending\n")
  (check-equal? (run (string-append timing "interface \"Separate\" [must [timing = unknown] must [Timing]]\ntrial = Separate.[Timing = 2]\nprint trial.timing\nprint trial.Timing\n")) "unknown\n2\n")
  (check-equal? (run (string-append timing "interface \"Assigned\" [must [timing = unknown Timing = 2]]\ntrial = Assigned.[]\nprint trial.timing\nprint trial.Timing\n")) "unknown\n2\n")
  (check-equal? (outcomes "interface \"Optional\" [period = unknown notes is text]\ntrial = [period = unknown notes = 2]\ntrial implement Optional\n") '(violated))
  (check-equal? (outcomes "interface \"Condition\" [must [period = unknown period == unknown]]\ntrial = [period = unknown]\ntrial implement Condition\n") '(satisfied))
  ;; Recognition uses declared names, not capitalization.
  (check-equal? (run "interface \"Experiment\" [must [timing = unknown timing-shape]]\ninterface \"timing-shape\" [must [period is number]]\ntrial = Experiment.[timing = [period = 2]]\nprint trial is Experiment\n") "true\n")

  (check-equal? (run "interface \"Protocol\" [must [timing [must [period is number]]]]\ninterface \"Experiment\" [must [timing = unknown Protocol.timing]]\ntrial = Experiment.[timing = [period = 2]]\nprint trial is Experiment\n") "true\n")
  (check-exn #rx"unknown interface Protocol.period after unknown default"
             (lambda () (run "interface \"Protocol\" [must [period is number]]\ninterface \"Experiment\" [must [timing = unknown Protocol.period]]\n")))

  ;; Nested groups, inheritance, branches, and per-item defaults share the rule.
  (check-equal? (run (string-append timing "interface \"Nested\" [must [details [must [timing = unknown Timing]]]]\ntrial = Nested.[]\nprint trial.details.timing\n")) "unknown\n")
  (check-equal? (outcomes (string-append timing "interface \"Nested\" [must [details [must [timing = unknown Timing]]]]\ntrial = [details = [timing = [period = -1 unit = \"seconds\"]]]\ntrial implement Nested\n")) '(violated))
  (check-equal? (run (string-append timing experiment "interface \"Inherited\" [extends Experiment]\ntrial = Inherited.[]\nprint trial.timing\n")) "unknown\n")
  (check-equal? (outcomes (string-append timing experiment "interface \"Inherited\" [extends Experiment]\ntrial = [timing = 2]\ntrial implement Inherited\n")) '(violated))
  (check-equal? (outcomes (string-append timing experiment "interface \"Changed\" [extends Experiment must [timing = unknown]]\ntrial = [timing = 2]\ntrial implement Changed\n")) '(satisfied))
  (define conditional (string-append timing "interface \"Conditional\" [must [enabled] if enabled [must [timing = unknown Timing]]]\n"))
  (check-equal? (outcomes (string-append conditional "trial = [enabled = false timing = 2]\ntrial implement Conditional\n")) '(satisfied))
  (check-equal? (outcomes (string-append conditional "trial = [enabled = true timing = 2]\ntrial implement Conditional\n")) '(violated))
  (check-equal? (run (string-append conditional "trial = Conditional.[enabled = true]\nprint trial.timing\n")) "unknown\n")
  (define series (string-append timing "interface \"Series\" [for each item in trials [must [item.timing = unknown Timing]]]\n"))
  (check-equal? (run (string-append series "series = Series.[trials = [[other = 1]]]\nprint series.trials.[1].timing\n")) "unknown\n")
  (check-equal? (outcomes (string-append series "series = [trials = [[timing = unknown] [timing = [period = 2 unit = \"seconds\"]]]]\nseries implement Series\n")) '(satisfied))
  (check-equal? (outcomes (string-append series "series = [trials = [[other = 1]]]\nseries implement Series\n")) '(violated))

  (with-source (string-append timing experiment "stage \"Inspect\"\n\"Inspect\" implement Experiment\n")
    (lambda (file)
      (define model (read-workflow-model file))
      (define interface (mapping-model-interface (first (workflow-model-mappings model))))
      (define fields (filter (lambda (condition) (eq? (condition-model-kind condition) 'required-entry))
                             (interface-model-conditions interface)))
      (check-equal? (map condition-model-target fields) '(timing))
      (check-equal? (condition-model-evidence (car fields)) '(typed-default Timing ((literal unknown))))))

  ;; Included and imported definitions, including private dependencies, resolve
  ;; before the candidate suffix is classified as a type or ordinary field.
  (define directory (make-temporary-file "sciencelogo-interface-default-library-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define base (build-path directory "timing"))
      (define combined (build-path directory "experiment"))
      (make-directory base)
      (make-directory combined)
      (define (git repo . args)
        (unless (zero? (parameterize ([current-output-port (open-output-string)]
                                     [current-error-port (open-output-string)])
                         (apply system*/exit-code (find-executable-path "git") "-C" (path->string repo) args)))
          (error 'interface-default-library "Git failed")))
      (define (tag repo)
        (git repo "init" "--initial-branch=main")
        (git repo "add" ".")
        (git repo "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid" "commit" "--quiet" "-m" "Define interface defaults")
        (git repo "tag" "v1"))
      (display-to-file (string-append "#lang sciencelogo\n" timing) (build-path base "types.rkt"))
      (display-to-file (string-append "#lang sciencelogo\nlibrary \"timing\" [" experiment "include \"types.rkt\"]\n")
                       (build-path base "library.rkt"))
      (tag base)
      (define base-import (format "import ~s at \"v1\" as clock\n" (format "file://~a" base)))
      (check-equal? (run (string-append base-import "trial = clock.Experiment.[]\nprint trial.timing\nprint trial is clock.Experiment\n")) "unknown\ntrue\n")
      (check-equal? (outcomes (string-append base-import "trial = [timing = 2]\ntrial implement clock.Experiment\n")) '(violated))
      (check-equal? (outcomes (string-append base-import "interface \"Local\" [must [timing = unknown clock.Timing]]\ntrial = [timing = [period = 2 unit = \"seconds\"]]\ntrial implement Local\n")) '(satisfied))
      (display-to-file (string-append "#lang sciencelogo\nlibrary \"experiment\" [" base-import
                                      "interface \"Experiment\" [must [timing = unknown clock.Timing]]]\n")
                       (build-path combined "library.rkt"))
      (tag combined)
      (define combined-import (format "import ~s at \"v1\" as experiments\n" (format "file://~a" combined)))
      (check-equal? (run (string-append combined-import "trial = experiments.Experiment.[]\nprint trial.timing\ntrial.timing = [period = 2 unit = \"seconds\"]\nprint trial is experiments.Experiment\n")) "unknown\ntrue\n")
      (check-equal? (outcomes (string-append combined-import "trial = [timing = 2]\ntrial implement experiments.Experiment\n")) '(violated))
      (check-exn #rx"dependency is private"
                 (lambda () (run (string-append combined-import "interface \"Local\" [must [timing = unknown experiments.clock.Timing]]\n"))))
      (define workflow-file (build-path base "workflow.rkt"))
      (display-to-file (string-append "#lang sciencelogo\n" experiment "include \"types.rkt\"\ntrial = [timing = unknown]\ntrial implement Experiment\n") workflow-file)
      (check-equal? (map condition-check-outcome (assessment-checks (assess-file workflow-file))) '(satisfied)))
    (lambda () (delete-directory/files directory)))

  (check-equal? (with-output-to-string (lambda () (dynamic-require example #f))) "true\n2\n")
  (check-equal? (assessment-findings (assess-file example)) '()))
