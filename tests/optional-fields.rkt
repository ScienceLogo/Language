#lang racket/base

(require "git-fixture.rkt"
         rackunit racket/file racket/list racket/port racket/runtime-path racket/system
         "../assessor.rkt" "../workflow-model.rkt")

(define-runtime-path example "../examples/optional-fields.rkt")
(define timing "interface Timing [must [period is number] notes is text]\n")
(define review "interface Review [must [reviewer is text]]\n")
(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-optional-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"Optional fields\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))
(define (run body)
  (with-source body (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))
(define (outcomes body)
  (with-source body (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))

(module+ test
  ;; An optional constraint supplies neither a field nor a default.
  (for ([kind (in-list '(number text boolean list record))]
        [value (in-list '("2" "\"notes\"" "false" "[1 2]" "[period = 2]"))]
        [wrong (in-list '("\"two\"" "2" "0" "[period = 2]" "[1 2]"))])
    (define declaration (format "interface Value [value is ~a]\n" kind))
    (check-equal? (run (string-append declaration "trial = Value.[]\nprint value in trial\nprint trial is Value\n"))
                  "false\ntrue\n")
    (check-equal? (outcomes (string-append declaration "trial = [other = 1]\ntrial implement Value\n")) '(satisfied))
    (check-not-exn (lambda () (run (string-append declaration "trial = Value.[value = " value "]\n"))))
    (check-equal? (outcomes (string-append declaration "trial = [value = " value "]\ntrial implement Value\n")) '(satisfied))
    (check-exn #rx"does not satisfy value requirement"
               (lambda () (run (string-append declaration "trial = Value.[value = " wrong "]\n"))))
    (check-equal? (outcomes (string-append declaration "trial = [value = " wrong "]\ntrial implement Value\n")) '(violated))
    (check-equal? (run (string-append declaration "print [value = unknown] is Value\n")) "unknown\n")
    (check-equal? (outcomes (string-append declaration "trial = [value = unknown]\ntrial implement Value\n")) '(undetermined)))

  ;; Inside must the same expression remains required, with its existing rules.
  (check-equal? (outcomes "interface Required [must [notes is text]]\ntrial = [other = 1]\ntrial implement Required\n") '(violated))
  (check-equal? (outcomes "interface Required [must [notes is text]]\ntrial = [notes = unknown]\ntrial implement Required\n") '(violated))
  (check-equal? (outcomes "interface Default [notes = \"default\"]\ntrial = [other = 1]\ntrial implement Default\n") '(violated))
  (check-equal? (outcomes "interface Unconstrained [notes]\ntrial = [notes = unknown]\ntrial implement Unconstrained\n") '(satisfied))
  (check-exn #rx"undetermined value requirement"
             (lambda () (run (string-append timing "trial = Timing.[period = 2 notes = unknown]\n"))))
  (check-equal? (outcomes (string-append timing "to write-notes [output \"notes\"]\ndo write-notes as notes\ntrial = [period = 2 notes = notes]\ntrial implement Timing\n")) '(undetermined))
  (check-equal? (run (string-append timing "trial = Timing.[period = 2 notes = \"first\"]\ntrial.notes = 3\nprint trial is Timing\n")) "false\n")

  ;; Named interfaces remain structural checks; they do not complete an object.
  (define with-review "interface Timing [must [period is number] review is Review]\n")
  (check-equal? (run (string-append with-review review "trial = Timing.[period = 2]\nprint review in trial\n")) "false\n")
  (for ([value (in-list '("[reviewer = \"human\"]" "[other = 1]" "2" "unknown"))]
        [expected (in-list '(satisfied violated violated undetermined))])
    (check-equal? (outcomes (string-append review with-review "trial = [period = 2 review = " value "]\ntrial implement Timing\n"))
                  (list expected)))
  (check-exn #rx"unknown interface Missing after is"
             (lambda () (run "interface Timing [review is Missing]\n")))
  (check-exn #rx"duplicate interface field notes"
             (lambda () (run "interface Timing [notes is text notes]\n")))

  ;; Nested groups, conditional branches, and list items skip absent fields.
  (define nested "interface Timing [must [period is number] details [notes is text]]\n")
  (for ([fields (in-list '("period = 2" "period = 2 details = [other = 1]"
                          "period = 2 details = [notes = \"notes\"]"))])
    (check-equal? (outcomes (string-append nested "trial = [" fields "]\ntrial implement Timing\n")) '(satisfied)))
  (check-equal? (outcomes (string-append nested "trial = [period = 2 details = [notes = 3]]\ntrial implement Timing\n")) '(violated))
  (check-equal? (outcomes (string-append nested "trial = [period = 2 details = [notes = unknown]]\ntrial implement Timing\n")) '(undetermined))
  (define conditional "interface Timing [must [enabled] if enabled [notes is text]]\n")
  (check-equal? (outcomes (string-append conditional "trial = [enabled = true]\ntrial implement Timing\n")) '(satisfied))
  (check-equal? (outcomes (string-append conditional "trial = [enabled = false notes = 3]\ntrial implement Timing\n")) '(satisfied))
  (check-equal? (outcomes (string-append conditional "trial = [enabled = true notes = 3]\ntrial implement Timing\n")) '(violated))
  (check-equal? (run (string-append conditional "trial = Timing.[enabled = false notes = 3]\nprint trial.notes\n")) "3\n")
  (define series "interface Series [for each item in trials [item.notes is text]]\n")
  (check-equal? (outcomes (string-append series "series = [trials = [[period = 2] [notes = \"notes\"]]]\nseries implement Series\n")) '(satisfied))
  (check-equal? (outcomes (string-append series "series = [trials = [[period = 2] [notes = 3]]]\nseries implement Series\n")) '(violated))
  (check-equal? (outcomes (string-append series "series = [trials = [[notes = unknown]]]\nseries implement Series\n")) '(undetermined))
  (check-equal? (outcomes (string-append review "interface Series [for each item in trials [item.review is Review]]\nseries = [trials = [[period = 2] [review = [reviewer = \"human\"]]]]\nseries implement Series\n")) '(satisfied))

  (check-equal? (outcomes "interface Base [notes is text]\ninterface Inherited [extends Base]\ntrial = [notes = 3]\ntrial implement Inherited\n") '(violated))
  (check-equal? (outcomes "interface Base [notes is text]\ninterface Changed [extends Base notes is number]\ntrial = [notes = 3]\ntrial implement Changed\n") '(satisfied))
  (check-equal? (run "interface Base [notes is text]\ninterface Changed [extends Base notes is number]\ntrial = Changed.[]\nprint notes in trial\n") "false\n")
  (check-exn #rx"conflicting inherited field notes"
             (lambda () (run "interface Text [notes is text]\ninterface Numeric [notes is number]\ninterface Combined [extends Text extends Numeric]\n")))

  ;; The model keeps presence and constraints separate, with no inferred must.
  (with-source (string-append timing "stage Inspect\nInspect implement Timing\n")
    (lambda (file)
      (define model (read-workflow-model file))
      (define interface (mapping-model-interface (first (workflow-model-mappings model))))
      (define entry
        (findf (lambda (condition) (and (eq? (condition-model-kind condition) 'optional-entry)
                                       (eq? (condition-model-target condition) 'notes)))
               (interface-model-conditions interface)))
      (define constraint
        (findf (lambda (condition) (eq? (condition-model-kind condition) 'field-constraint))
               (interface-model-conditions interface)))
      (check-false (condition-model-evidence entry))
      (check-equal? (condition-model-evidence constraint) '(kind-test text ((result notes))))
      (check-equal? (condition-model-scope constraint) (condition-model-id entry))
      (check-false (ormap (lambda (condition) (and (eq? (condition-model-kind condition) 'required-entry)
                                                  (eq? (condition-model-target condition) 'notes)))
                          (interface-model-conditions interface)))))
  (check-equal? (outcomes "interface Protocol [must [measurement] notes is text]\nstage Measure\nMeasure implement Protocol.measurement\n") '(satisfied))
  (check-equal? (outcomes "interface Protocol [must [measurement] notes is text]\nstage Measure\nMeasure implement Protocol.measurement\nMeasure implement Protocol.notes\n") '(satisfied undetermined))

  ;; Standalone interface files reconstruct their optional checks from the model.
  (define directory (make-temporary-file "sciencelogo-optional-library-~a" 'directory))
  (with-git-fixture
    void
    (lambda ()
      (define interface-file (build-path directory "timing.rkt"))
      (display-to-file (string-append "#lang sciencelogo\n" timing) interface-file)
      (define workflow-file (build-path directory "workflow.rkt"))
      (for ([fields (in-list '("period = 2" "period = 2 notes = \"notes\"" "period = 2 notes = 3" "period = 2 notes = unknown"))]
            [expected (in-list '(satisfied satisfied violated undetermined))])
        (display-to-file (string-append "#lang sciencelogo\ntrial = [" fields "]\ntrial implement \"timing.rkt\"\n")
                         workflow-file #:exists 'truncate)
        (check-equal? (map condition-check-outcome (assessment-checks (assess-file workflow-file))) (list expected)))
      (display-to-file (string-append "#lang sciencelogo\nlibrary timing [" review with-review
                                      "interface Series [for each item in trials [item.review is Review]]]\n")
                       (build-path directory "library.rkt"))
      (define (git . args)
        (unless (zero? (parameterize ([current-output-port (open-output-string)]
                                     [current-error-port (open-output-string)])
                         (apply system*/exit-code (find-executable-path "git") "-C" (path->string directory) args)))
          (error 'optional-library "Git failed")))
      (git "init" "--initial-branch=main")
      (git "add" "library.rkt")
      (git "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid" "commit" "--quiet" "-m" "Define optional interface fields")
      (git "tag" "v1")
      (define imported (format "import ~s at \"v1\" as timing\n" (format "file://~a" directory)))
      (check-equal? (run (string-append imported "trial = timing.Timing.[period = 2]\nprint review in trial\ntrial.review = [reviewer = \"human\"]\nprint trial is timing.Timing\n")) "false\ntrue\n")
      (check-equal? (outcomes (string-append imported "trial = [period = 2 review = [other = 1]]\ntrial implement timing.Timing\n")) '(violated))
      (check-equal? (outcomes (string-append imported "series = [trials = [[period = 2] [review = [reviewer = \"human\"]]]]\nseries implement timing.Series\n")) '(satisfied)))
    (lambda () (delete-directory/files directory)))

  (check-equal? (with-output-to-string (lambda () (dynamic-require example #f))) "false\ntrue\n")
  (check-equal? (assessment-findings (assess-file example)) '()))
