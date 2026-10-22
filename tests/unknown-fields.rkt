#lang racket/base

(require rackunit racket/file racket/list racket/port racket/system racket/runtime-path
         "../assessor.rkt" "../workflow-model.rkt")

(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-unknown-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"Required values\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))
(define (run body)
  (with-source body (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))
(define (outcomes body)
  (with-source body (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))
(define required "interface Timing [must [period]]\n")
(define defaulted "interface Timing [must [period = 2]]\n")
(define permitted "interface Timing [must [period = unknown]]\n")
(define-runtime-path example "../examples/unknown-fields.rkt")

(module+ test
  (check-equal? (with-output-to-string (lambda () (dynamic-require example #f))) "")
  (check-equal? (assessment-findings (assess-file example)) '())
  (check-equal? (run (string-append required "trial = Timing.[period = 2]\nprint trial.period\n")) "2\n")
  (check-exn #rx"does not allow unknown.*period"
             (lambda () (run (string-append required "trial = Timing.[period = unknown]\n"))))
  (check-equal? (run (string-append defaulted "trial = Timing.[]\nprint trial.period\n")) "2\n")
  (check-exn #rx"does not allow unknown.*period"
             (lambda () (run (string-append defaulted "trial = Timing.[period = unknown]\n"))))
  (check-equal? (run (string-append permitted "trial = Timing.[]\nprint trial.period\n")) "unknown\n")
  (check-equal? (run (string-append permitted "trial = Timing.[period = 2]\nprint trial.period\n")) "2\n")
  (check-equal? (run (string-append permitted "trial = Timing.[period = unknown]\nprint trial.period\n")) "unknown\n")
  (check-equal? (outcomes (string-append required "trial = [period = unknown]\ntrial implement Timing\n")) '(violated))
  (check-equal? (outcomes (string-append defaulted "trial = [period = unknown]\ntrial implement Timing\n")) '(violated))
  (check-equal? (outcomes (string-append permitted "trial = [period = unknown]\ntrial implement Timing\n")) '(satisfied))
  (check-equal? (outcomes (string-append permitted "trial = [note = \"not supplied\"]\ntrial implement Timing\n")) '(violated))
  (with-source (string-append required "trial = [period = unknown]\ntrial implement Timing\n")
    (lambda (file)
      (define report (assess-file file))
      (check-equal? (map finding-kind (assessment-findings report)) '(unknown-field))
      (check-equal? (finding-part (first (assessment-findings report))) '(period))
      (check-regexp-match #rx"has unknown field.*period.*does not permit"
                          (with-output-to-string (lambda () (render-assessment report))))))

  ;; False, zero, text, and containers are supplied values. Their contents are
  ;; governed by any additional declarations, not an implicit recursive ban.
  (for ([value (in-list '("false" "0" "\"unknown\"" "[]" "[unknown]" "[estimate = unknown]"))])
    (check-not-exn (lambda () (run (string-append required "trial = Timing.[period = " value "]\n")))))
  (check-equal? (run "interface Optional [must [period] note]\ntrial = Optional.[period = 2 note = unknown]\nprint trial.note\n")
                "unknown\n")
  (check-equal? (outcomes (string-append required "value = unknown\ntrial = [period = value]\ntrial implement Timing\n"))
                '(violated))
  (check-equal? (outcomes (string-append required "to choose [output 2]\ndo choose as value\ntrial = [period = value]\ntrial implement Timing\n"))
                '(undetermined))
  (check-equal? (outcomes (string-append permitted "to choose [output 2]\ndo choose as value\ntrial = [period = value]\ntrial implement Timing\n"))
                '(satisfied))

  (check-equal? (outcomes "interface Positive [must [period > 0]]\ntrial = [period = unknown]\ntrial implement Positive\n")
                '(violated))
  (check-equal? (outcomes "interface Positive [must [period = unknown period > 0]]\ntrial = [period = unknown]\ntrial implement Positive\n")
                '(undetermined))
  (check-equal? (outcomes "interface Summary [must [trial.count > 0]]\nvalue = [trial = [count = unknown]]\nvalue implement Summary\n")
                '(violated))
  (check-equal? (outcomes "interface Summary [must [trial.count = unknown trial.count > 0]]\nvalue = [trial = [count = unknown]]\nvalue implement Summary\n")
                '(undetermined))
  (check-equal? (outcomes "interface Series [must [measurements = unknown measurements.count >= 3]]\nvalue = [measurements = unknown]\nvalue implement Series\n")
                '(undetermined))
  (check-equal? (outcomes "interface Choice [must [accepted or true]]\ntrial = [accepted = unknown]\ntrial implement Choice\n")
                '(violated))
  (check-equal? (outcomes "interface Choice [must [accepted = unknown accepted or true]]\ntrial = [accepted = unknown]\ntrial implement Choice\n")
                '(satisfied))

  (check-equal? (run "interface Nested [must [timing [must [period = unknown]]]]\ntrial = Nested.[]\nprint trial.timing.period\n")
                "unknown\n")
  (check-equal? (outcomes "interface Nested [must [timing [must [period]]]]\ntrial = [timing = [period = unknown]]\ntrial implement Nested\n")
                '(violated))
  (check-equal? (outcomes "interface Nested [must [timing.period = unknown]]\ntrial = [timing = [period = unknown]]\ntrial implement Nested\n")
                '(satisfied))
  (check-equal? (outcomes "interface Series [must [measurements] for each m in measurements [must [m.period]]]\ntrial = [measurements = [[period = unknown]]]\ntrial implement Series\n")
                '(violated))
  (check-equal? (run "interface Series [must [measurements] for each m in measurements [must [m.period = unknown]]]\ntrial = Series.[measurements = [[note = \"planned\"]]]\nprint trial.measurements.[1].period\n")
                "unknown\n")
  (check-equal? (outcomes "interface Series [must [measurements] for each m in measurements [must [m.period = unknown]]]\ntrial = [measurements = [[period = unknown]]]\ntrial implement Series\n")
                '(satisfied))

  (check-exn #rx"does not allow unknown"
             (lambda () (run (string-append required "trial = Timing.[period = unknown u []]\n"))))
  (check-equal? (run (string-append permitted "trial = Timing.[period = unknown u []]\nprint trial.period.u.declared\n")) "[]\n")
  (check-equal? (run "interface Qualified [must [period = unknown u []]]\ntrial = Qualified.[]\nprint trial.period.u.declared\n") "[]\n")
  (check-equal? (run (string-append permitted "interface Inherited [extends Timing]\ntrial = Inherited.[]\nprint trial.period\n")) "unknown\n")
  (check-exn #rx"does not allow unknown"
             (lambda () (run (string-append permitted "interface Strict [extends Timing must [period]]\ntrial = Strict.[period = unknown]\n"))))

  ;; An inactive requirement does not forbid an additional unknown field.
  (check-equal? (outcomes "interface Conditional [must [enabled] if enabled [must [period]]]\ntrial = [enabled = false period = unknown]\ntrial implement Conditional\n")
                '(satisfied))
  (check-equal? (outcomes "interface Conditional [must [enabled] if enabled [must [period]]]\ntrial = [enabled = true period = unknown]\ntrial implement Conditional\n")
                '(violated))
  (check-equal? (outcomes "interface Conditional [must [enabled = unknown] if enabled [must [period]]]\ntrial = [enabled = unknown period = unknown]\ntrial implement Conditional\n")
                '(undetermined))
  (check-equal? (run "interface Conditional [must [enabled] if enabled [must [period = unknown]]]\ntrial = Conditional.[enabled = true]\nprint trial.period\n") "unknown\n")

  ;; The written default is retained for independent applications to inspect.
  (with-source (string-append permitted "stage Measure\nMeasure implement Timing\n")
    (lambda (file)
      (define model (read-workflow-model file))
      (define interface (mapping-model-interface (first (workflow-model-mappings model))))
      (check-equal? (condition-model-evidence (first (interface-model-conditions interface))) '(literal unknown))))

  (define directory (make-temporary-file "sciencelogo-unknown-library-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (display-to-file (string-append "#lang sciencelogo\nlibrary timing [" permitted "]\n")
                       (build-path directory "library.rkt"))
      (display-to-file (string-append "#lang sciencelogo\n" permitted) (build-path directory "timing.rkt"))
      (define (git . args)
        (unless (zero? (parameterize ([current-output-port (open-output-string)]
                                     [current-error-port (open-output-string)])
                         (apply system*/exit-code (find-executable-path "git") "-C" (path->string directory) args)))
          (error 'unknown-library "Git failed")))
      (git "init" "--initial-branch=main")
      (git "add" "library.rkt" "timing.rkt")
      (git "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid" "commit" "--quiet" "-m" "Allow unknown explicitly")
      (git "tag" "v1")
      (define body (format "import ~s at \"v1\" as timing\ntrial = timing.Timing.[]\ntrial implement timing.Timing\nprint trial.period\n"
                            (format "file://~a" directory)))
      (check-equal? (run body) "unknown\n")
      (check-equal? (outcomes body) '(satisfied))
      (define file (build-path directory "workflow.rkt"))
      (display-to-file "#lang sciencelogo\ntrial = [period = unknown]\ntrial implement \"timing.rkt\"\n" file)
      (check-equal? (map condition-check-outcome (assessment-checks (assess-file file))) '(satisfied)))
    (lambda () (delete-directory/files directory))))
