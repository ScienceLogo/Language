#lang racket/base

(require "git-fixture.rkt"
         rackunit racket/file racket/list racket/port racket/runtime-path racket/system
         "../assessor.rkt" "../workflow-model.rkt")

(define-runtime-path example "../examples/value-kinds.rkt")
(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-kinds-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"Value kinds\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))
(define (run body)
  (with-source body (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))
(define (outcomes body)
  (with-source body (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))

(module+ test
  ;; One declaration rule covers each of the five broad kinds.
  (for ([kind (in-list '(number text boolean list record))]
        [default (in-list '("2" "\"seconds\"" "true" "[1]" "[period = 2]"))]
        [replacement (in-list '("3.5" "\"minutes\"" "false" "[\"manual\"]" "[notes = \"pending\"]"))]
        [wrong (in-list '("\"two\"" "2" "\"true\"" "[period = 2]" "[1]"))])
    (define required (format "interface Value [must [value is ~a]]\n" kind))
    (define inferred (format "interface Value [must [value = ~a]]\n" default))
    (define pending (format "interface Value [must [value = unknown ~a]]\n" kind))
    (check-not-exn (lambda () (run (string-append required "trial = Value.[value = " replacement "]\n"))))
    (check-exn #rx"does not satisfy value requirement"
               (lambda () (run (string-append required "trial = Value.[value = " wrong "]\n"))))
    (check-not-exn (lambda () (run (string-append inferred "trial = Value.[]\n"))))
    (check-not-exn (lambda () (run (string-append inferred "trial = Value.[value = " replacement "]\n"))))
    (check-exn #rx"wrong kind.*value"
               (lambda () (run (string-append inferred "trial = Value.[value = " wrong "]\n"))))
    (check-equal? (outcomes (string-append inferred "trial = [value = " wrong "]\ntrial implement Value\n"))
                  '(violated))
    (check-equal? (run (string-append pending "trial = Value.[]\nprint trial.value\n")) "unknown\n")
    (check-not-exn (lambda () (run (string-append pending "trial = Value.[value = " replacement "]\n"))))
    (check-exn #rx"wrong kind.*value"
               (lambda () (run (string-append pending "trial = Value.[value = " wrong "]\n"))))
    (check-equal? (outcomes (string-append pending "trial = [value = unknown]\ntrial implement Value\n"))
                  '(satisfied)))

  (check-equal? (run "print 2 is number\nprint \"2\" is number\nprint [unknown] is list\nprint [period = unknown] is record\nprint unknown is number\nprint not 2 is text\nprint 1 + 2 is number and true\n")
                "true\nfalse\ntrue\ntrue\nunknown\ntrue\ntrue\n")
  (check-equal? (run "to numeric :value [output :value is number]\ndo numeric 2 as accepted\nprint accepted\nvalue = \"two\"\nif value is number [print \"number\"] else if value is text [print \"text\"]\n")
                "true\ntext\n")
  (check-equal? (run "number = 2\ntext = \"label\"\nprint number is number\nprint text is text\n")
                "true\ntrue\n")
  (check-exn #rx"unknown interface integer after is"
             (lambda () (run "print 2 is integer\n")))
  (check-exn #rx"comparison cannot be chained"
             (lambda () (run "print 2 is number == true\n")))
  (check-exn exn:fail:read? (lambda () (run "print missing is number\n")))
  (check-exn #rx"missing field.*period"
             (lambda () (run "interface Timing [must [period is number]]\ntrial = Timing.[]\n")))
  (check-equal? (run "interface Timing [must [period = unknown]]\ntrial = Timing.[period = \"not yet numeric\"]\nprint trial.period\n")
                "not yet numeric\n")
  (check-equal? (outcomes "interface Timing [must [period = unknown number period > 0]]\ntrial = [period = unknown]\ntrial implement Timing\n")
                '(undetermined))
  (check-equal? (outcomes "interface Timing [must [period = unknown period is number]]\ntrial = [period = unknown]\ntrial implement Timing\n")
                '(undetermined))
  (check-equal? (outcomes "interface Timing [must [period = unknown number]]\nto choose [output 2]\ndo choose as value\ntrial = [period = value]\ntrial implement Timing\n")
                '(undetermined))
  (check-equal? (run "interface Timing [must [period = 2 u []]]\ntrial = Timing.[period = 3 u []]\nprint trial.period is number\n")
                "true\n")
  (check-equal? (run "interface Timing [must [period = unknown u [] number]]\ntrial = Timing.[]\nprint trial.period is number\n")
                "unknown\n")
  (check-equal? (run "interface Timing [must [period = 1 + 1]]\ntrial = Timing.[period = 3]\nprint trial.period\n")
                "3\n")
  (check-exn #rx"wrong kind.*period"
             (lambda () (run "default-period = 2\ninterface Timing [must [period = default-period]]\ntrial = Timing.[period = \"two\"]\n")))
  (check-equal? (run "default-period = 2\ninterface Timing [must [period = default-period]]\ntrial = Timing.[period = 3]\nprint trial.period\n")
                "3\n")

  ;; Named groups and per-item declarations retain both kind and permission.
  (check-equal? (run "interface Nested [must [timing [must [period = unknown number]]]]\ntrial = Nested.[]\nprint trial.timing.period\n")
                "unknown\n")
  (check-equal? (outcomes "interface Nested [must [timing [must [period = 2]]]]\ntrial = [timing = [period = \"two\"]]\ntrial implement Nested\n")
                '(violated))
  (check-equal? (run "interface Series [for each item in measurements [must [item.period = unknown number]]]\nseries = Series.[measurements = [[note = \"planned\"]]]\nprint series.measurements.[1].period\n")
                "unknown\n")
  (check-equal? (outcomes "interface Series [for each item in measurements [must [item.period = 2]]]\nseries = [measurements = [[period = \"two\"]]]\nseries implement Series\n")
                '(violated))
  (check-equal? (outcomes "interface Conditional [must [enabled] if enabled [must [period = 2]]]\ntrial = [enabled = false period = \"two\"]\ntrial implement Conditional\n")
                '(satisfied))
  (check-equal? (outcomes "interface Conditional [must [enabled] if enabled [must [period = 2]]]\ntrial = [enabled = true period = \"two\"]\ntrial implement Conditional\n")
                '(violated))
  (check-equal? (run "interface Base [must [period = unknown number]]\ninterface Inherited [extends Base]\ntrial = Inherited.[period = 2]\nprint trial.period\n")
                "2\n")
  (check-equal? (run "interface Base [must [period = 2]]\ninterface Changed [extends Base must [period = \"pending\"]]\ntrial = Changed.[]\nprint trial.period\n")
                "pending\n")
  ;; A later update is checked when the object is checked against the interface.
  (with-source
    (string-append "performer researcher [kind = \"human\"]\nto keep :value [output :value]\n"
                   "stage Measure by researcher from state [information = [period = 2]]\n"
                   "if information.period is number [do keep with [value at information.period] into information.period]\n"
                   "end stage with state [information = [period = 2]]\n")
    (lambda (file) (check-not-exn (lambda () (read-workflow-model file)))))
  (with-source "interface Timing [must [period = 2]]\ntrial = Timing.[]\ntrial.period = \"two\"\ntrial implement Timing\n"
    (lambda (file)
      (define report (assess-file file))
      (check-equal? (map finding-kind (assessment-findings report)) '(wrong-field-kind))
      (check-regexp-match #rx"wrong kind of value"
                          (with-output-to-string (lambda () (render-assessment report))))))

  (with-source "interface Timing [must [period = unknown number unit is text]]\nstage Measure\nMeasure implement Timing\n"
    (lambda (file)
      (define model (read-workflow-model file))
      (define interface (mapping-model-interface (first (workflow-model-mappings model))))
      (define conditions (interface-model-conditions interface))
      (check-equal? (condition-model-evidence
                    (findf (lambda (condition) (eq? (condition-model-target condition) 'period)) conditions))
                    '(typed-default number ((literal unknown))))
      (check-equal? (map condition-model-evidence
                        (filter (lambda (condition) (eq? (condition-model-kind condition) 'value-requirement)) conditions))
                    '((kind-test text ((result unit)))))))

  (define directory (make-temporary-file "sciencelogo-kinds-library-~a" 'directory))
  (with-git-fixture
    void
    (lambda ()
      (define declaration "interface Timing [must [period = unknown number unit = \"seconds\"]]\n")
      (display-to-file (string-append "#lang sciencelogo\nlibrary timing [" declaration
                                      "to numeric :value [output :value is number]]\n")
                       (build-path directory "library.rkt"))
      (display-to-file (string-append "#lang sciencelogo\n" declaration) (build-path directory "timing.rkt"))
      (define (git . args)
        (unless (zero? (parameterize ([current-output-port (open-output-string)]
                                     [current-error-port (open-output-string)])
                         (apply system*/exit-code (find-executable-path "git") "-C" (path->string directory) args)))
          (error 'kind-library "Git failed")))
      (git "init" "--initial-branch=main")
      (git "add" "library.rkt" "timing.rkt")
      (git "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid" "commit" "--quiet" "-m" "Describe numeric periods")
      (git "tag" "v1")
      (define body (format "import ~s at \"v1\" as timing\ntrial = timing.Timing.[]\ntrial implement timing.Timing\ndo timing.numeric 2 as accepted\nprint accepted\n"
                            (format "file://~a" directory)))
      (check-equal? (run body) "true\n")
      (check-equal? (outcomes body) '(satisfied))
      (define file (build-path directory "workflow.rkt"))
      (display-to-file "#lang sciencelogo\ntrial = [period = \"two\" unit = \"seconds\"]\ntrial implement \"timing.rkt\"\n" file)
      (check-equal? (map condition-check-outcome (assessment-checks (assess-file file))) '(violated)))
    (lambda () (delete-directory/files directory)))
  (check-equal? (with-output-to-string (lambda () (dynamic-require example #f))) "")
  (check-equal? (assessment-findings (assess-file example)) '()))
