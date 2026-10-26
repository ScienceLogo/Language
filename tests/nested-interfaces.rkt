#lang racket/base

(require "git-fixture.rkt"
         rackunit racket/file racket/list racket/port racket/runtime-path racket/system
         "../assessor.rkt" "../workflow-model.rkt")

(define-runtime-path example "../examples/nested-interfaces.rkt")
(define timing "interface Timing [must [period is number unit = \"seconds\" period > 0]]\n")
(define experiment "interface Experiment [must [timing is Timing]]\n")
(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-nested-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"Nested interfaces\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))
(define (run body)
  (with-source body (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))
(define (outcomes body)
  (with-source body (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))

(module+ test
  ;; Matching uses structure, without requiring construction from the interface.
  ;; Known violations win over checks that remain unresolved.
  (for ([value (in-list '("[period = 2 unit = \"seconds\"]"
                         "[period = 2 unit = \"minutes\" notes = \"hand timed\"]"
                         "([period = 2 unit = \"seconds\"] u [])"))])
    (check-equal? (run (string-append timing "trial = " value "\nprint trial is Timing\n")) "true\n")
    (check-equal? (outcomes (string-append experiment timing "trial = [timing = " value "]\ntrial implement Experiment\n"))
                  '(satisfied)))
  (for ([value (in-list '("[period = 2]" "[unit = \"seconds\"]"
                         "[period = \"two\" unit = \"seconds\"]"
                         "[period = -2 unit = \"seconds\"]"
                         "[period = unknown unit = \"seconds\"]"
                         "2" "\"timing\"" "[1 2]" "false"))])
    (check-equal? (run (string-append timing "trial = " value "\nprint trial is Timing\n")) "false\n")
    (check-equal? (outcomes (string-append timing experiment "trial = [timing = " value "]\ntrial implement Experiment\n"))
                  '(violated)))
  (check-equal? (run (string-append timing "print unknown is Timing\n")) "unknown\n")
  ;; is supplies no default and never inserts fields into its operand.
  (check-equal? (run (string-append timing "trial = [period = 2]\nprint trial is Timing\nprint unit in trial\n"))
                "false\nfalse\n")
  (check-equal? (run (string-append experiment timing "timing = Timing.[period = 2]\ntrial = Experiment.[timing = timing]\nprint trial.timing.period\nprint trial is Experiment\n"))
                "2\ntrue\n")
  (check-exn #rx"does not satisfy value requirement"
             (lambda () (run (string-append timing experiment "trial = Experiment.[timing = [period = 2]]\n"))))
  (check-exn #rx"missing field.*timing"
             (lambda () (run (string-append timing experiment "trial = Experiment.[]\n"))))
  (check-equal? (run (string-append timing "to matches :value [output :value is Timing]\ndo matches [period = 2 unit = \"seconds\"] as accepted\nif accepted [print \"accepted\"]\nprint not [period = 0 unit = \"seconds\"] is Timing\nprint [period = 2 unit = \"seconds\"] is Timing and 2 is number\n"))
                "accepted\ntrue\ntrue\n")

  ;; Nested groups, inheritance, optional fields, and per-item rules are reused.
  (check-equal? (run (string-append timing "interface Detailed [extends Timing notes]\nprint [period = 2 unit = \"seconds\"] is Detailed\ninterface Group [must [timing [must [period is number]]]]\nprint [period = 2] is Group.timing\n"))
                "true\ntrue\n")
  (check-equal? (outcomes (string-append timing "interface Series [for each item in measurements [must [item is Timing]]]\nseries = [measurements = [[period = 2 unit = \"seconds\"] [period = 3 unit = \"minutes\"]]]\nseries implement Series\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append timing "interface Series [for each item in measurements [must [item is Timing]]]\nseries = [measurements = [[period = 2 unit = \"seconds\"] [period = -1 unit = \"seconds\"]]]\nseries implement Series\n"))
                '(violated))
  (check-equal? (outcomes (string-append timing "interface Conditional [must [timing] if timing is Timing [must [reviewer]] else [must [reason]]]\ntrial = [timing = [period = 2 unit = \"seconds\"] reviewer = \"human\"]\ntrial implement Conditional\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append timing "interface Conditional [must [timing] if timing is Timing [must [reviewer]] else [must [reason]]]\ntrial = [timing = [period = -1 unit = \"seconds\"] reason = \"invalid period\"]\ntrial implement Conditional\n"))
                '(satisfied))
  (check-equal? (run "interface Planned [must [period = unknown number]]\nprint [period = unknown] is Planned\ninterface Checked [must [period = unknown number period > 0]]\nprint [period = unknown] is Checked\n")
                "true\nunknown\n")
  (check-equal? (outcomes (string-append timing experiment "to measure [output 2]\ndo measure as period\ntrial = [timing = [period = period unit = \"seconds\"]]\ntrial implement Experiment\n"))
                '(undetermined))
  (check-equal? (outcomes (string-append timing experiment "to measure [output 2]\ndo measure as period\ntrial = [timing = [period = period]]\ntrial implement Experiment\n"))
                '(violated))
  ;; Cyclic tests have no independent answer; recursive records can still match.
  (check-equal? (run "interface Loop [must [[value = 1] is Loop]]\nprint [value = 1] is Loop\ninterface Node [must [value is number next = unknown] if next != unknown [must [next is Node]]]\nprint [value = 1 next = [value = 2 next = unknown]] is Node\n")
                "unknown\ntrue\n")

  ;; Misspelled or non-interface targets fail during reading, including defaults.
  (for ([body (in-list '("print 2 is Missing\n"
                         "interface Example [must [trial is Missing]]\n"
                         "interface Example [accepted = [period = 2] is Missing]\n"
                         "interface Example [period] print [period = 2] is Example.period\n"))])
    (check-exn #rx"unknown interface .* after is" (lambda () (run body))))
  (check-exn #rx"comparison cannot be chained"
             (lambda () (run (string-append timing "print [period = 2] is Timing == true\n"))))

  (with-source (string-append experiment timing "stage Inspect\nInspect implement Experiment\n")
    (lambda (file)
      (define model (read-workflow-model file))
      (define interface (mapping-model-interface (first (workflow-model-mappings model))))
      (define requirement
        (findf (lambda (condition) (eq? (condition-model-kind condition) 'value-requirement))
               (interface-model-conditions interface)))
      (check-equal? (condition-model-evidence requirement) '(kind-test Timing ((result timing))))
      (check-true (ormap (lambda (declaration) (equal? (cadr declaration) "Timing"))
                         (interface-model-declarations interface)))))

  ;; Imports keep references to local types and private dependency types.
  (define directory (make-temporary-file "sciencelogo-nested-libraries-~a" 'directory))
  (with-git-fixture
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
          (error 'nested-interface-library "Git failed")))
      (define (tag repo)
        (git repo "init" "--initial-branch=main")
        (git repo "add" ".")
        (git repo "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid"
             "commit" "--quiet" "-m" "Define reusable interfaces")
        (git repo "tag" "v1"))
      (display-to-file (string-append "#lang sciencelogo\n" timing) (build-path base "types.rkt"))
      (display-to-file
       (string-append "#lang sciencelogo\nlibrary timing [include \"types.rkt\"\n" experiment
                      "to accepted :value [output :value is Timing]\n"
                      "interface Series [for each item in measurements [must [item is Timing]]]\n"
                      "interface Conditional [must [timing] if timing is Timing [must [reviewer]] else [must [reason]]]\n]\n")
       (build-path base "library.rkt"))
      (tag base)
      (define base-import (format "import ~s at \"v1\" as timing\n" (format "file://~a" base)))
      (define input "[period = 2 unit = \"seconds\"]")
      (check-equal? (run (string-append base-import "print " input " is timing.Timing\ndo timing.accepted " input " as accepted\nprint accepted\ntrial = timing.Experiment.[timing = " input "]\ntrial implement timing.Experiment\n"))
                    "true\ntrue\n")
      (check-equal? (outcomes (string-append base-import "trial = [timing = " input "]\ntrial implement timing.Experiment\n"))
                    '(satisfied))
      (check-equal? (outcomes (string-append base-import "trial = [timing = [period = -1 unit = \"seconds\"]]\ntrial implement timing.Experiment\n"))
                    '(violated))
      (check-equal? (outcomes (string-append base-import "series = [measurements = [" input "]]\nseries implement timing.Series\n"))
                    '(satisfied))
      (check-equal? (outcomes (string-append base-import "trial = [timing = " input " reviewer = \"human\"]\ntrial implement timing.Conditional\n"))
                    '(satisfied))
      ;; The combined library's field refers to its imported Timing interface.
      (display-to-file
       (string-append "#lang sciencelogo\nlibrary experiment [" base-import
                      "interface Experiment [must [timing is timing.Timing]]\n"
                      "to accepted :value [output :value is timing.Timing]\n]\n")
       (build-path combined "library.rkt"))
      (tag combined)
      (define combined-import
        (format "import ~s at \"v1\" as experiments\n" (format "file://~a" combined)))
      (check-equal? (run (string-append combined-import "trial = experiments.Experiment.[timing = " input "]\nprint trial is experiments.Experiment\ndo experiments.accepted " input " as accepted\nprint accepted\n"))
                    "true\ntrue\n")
      (check-equal? (outcomes (string-append combined-import "trial = [timing = " input "]\ntrial implement experiments.Experiment\n"))
                    '(satisfied))
      (check-exn #rx"dependency is private"
                 (lambda () (run (string-append combined-import "print " input " is experiments.timing.Timing\n"))))

      ;; Includes resolve relative to their file; no new import syntax is needed.
      (define local (build-path base "workflow.rkt"))
      (display-to-file
       (string-append "#lang sciencelogo\ninclude \"types.rkt\"\n" experiment
                      "trial = [timing = " input "]\ntrial implement Experiment\n") local)
      (check-equal? (map condition-check-outcome (assessment-checks (assess-file local))) '(satisfied))
      (define retained
        (with-source (string-append combined-import "trial = [timing = " input "]\ntrial implement experiments.Experiment\n")
                     read-workflow-model))
      (delete-directory/files base)
      (delete-directory/files combined)
      (check-equal? (map condition-check-outcome (assessment-checks (assess-workflow retained))) '(satisfied)))
    (lambda () (delete-directory/files directory)))

  (check-equal? (with-output-to-string (lambda () (dynamic-require example #f))) "2\n")
  (check-equal? (assessment-findings (assess-file example)) '()))
