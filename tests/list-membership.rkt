#lang racket/base

(require rackunit racket/file racket/list racket/port racket/runtime-path racket/system
         "../assessor.rkt" "../workflow-model.rkt")

(define-runtime-path example "../examples/list-membership.rkt")
(define required "interface Timing [must [method in [\"manual\" \"video\"]]]\n")
(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-membership-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"Timing methods\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))
(define (run body)
  (with-source body (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))
(define (outcomes body)
  (with-source body (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))

(module+ test
  ;; Membership uses equality, including structured values, without coercion.
  (for ([expression (in-list '("2 in [1 2 3]" "2 in [2 2]"
                              "\"manual\" in [\"manual\" \"video\"]"
                              "[1 2] in [[1 2] [3]]"
                              "[unit = \"seconds\" period = 2] in [[period = 2 unit = \"seconds\"]]"
                              "(2 u []) in [2]" "2 in [2 u []]"))])
    (check-equal? (run (string-append "print " expression "\n")) "true\n"))
  (for ([expression (in-list '("4 in [1 2 3]" "1 in [\"1\"]" "false in [0]"
                              "\"Manual\" in [\"manual\"]" "1 in [[1 2]]"
                              "2 in []" "unknown in []"))])
    (check-equal? (run (string-append "print " expression "\n")) "false\n"))

  ;; Unknown is an explicit value, including when it is a list item.
  (for ([expression (in-list '("2 in [unknown 2]" "2 in [2 unknown]"
                              "2 in [[period = unknown] 2]"))])
    (check-equal? (run (string-append "print " expression "\n")) "true\n"))
  (for ([expression (in-list '("2 in [1 unknown]" "unknown in [1 2]"
                              "[period = unknown] in [[period = 2]]"))])
    (check-equal? (run (string-append "print " expression "\n")) "false\n"))
  (check-equal? (run "print unknown in [unknown]\n") "true\n")
  (check-equal? (run "print 2 in unknown\n") "unknown\n")

  (check-equal? (run "methods = [\"manual\" \"video\"]\nmethod = \"manual\"\naccepted = method in methods\nprint accepted\nmethods = [\"video\"]\nprint method in methods\n")
                "true\nfalse\n")
  (check-equal? (run "settings = [methods = [\"manual\" \"video\"]]\nprint \"manual\" in settings.methods\nlengths = range 0.25 to 1 step 0.25\nprint 0.5 in lengths\n")
                "true\ntrue\n")
  (check-equal? (run "to accepted :method :methods [output :method in :methods]\ndo accepted \"manual\" [\"manual\" \"video\"] as answer\nprint answer\n")
                "true\n")
  (check-equal? (run "print 1 + 1 in [2]\nprint not 2 in [1]\nprint 2 in [1 2] and 3 > 2\nprint false or 2 in [2]\nprint [(2 in [2]) (3 in [2])]\n")
                "true\ntrue\ntrue\ntrue\n[true false]\n")
  (check-equal? (run "method = \"video\"\nif method in [\"manual\"] [print \"manual\"] else if method in [\"video\"] [print \"video\"] else [print \"other\"]\nfor each value in [1 2] [print value in [2]]\ncount = 0\nwhile count in [0 1] [count += 1]\nrepeat [count += 1] until count in [3]\nprint count\n")
                "video\nfalse\ntrue\n3\n")
  (check-exn #rx"in needs a list or record on its right"
             (lambda () (run "print \"manual\" in \"manual\"\n")))
  (check-exn #rx"in needs an unquoted field name"
             (lambda () (run "print 1 in [method = \"manual\"]\n")))
  (check-exn #rx"comparison cannot be chained"
             (lambda () (run "print 1 in [1] == true\n")))
  (check-exn #rx"comparison cannot be chained"
             (lambda () (run "print 1 in [1] in [true]\n")))

  ;; Requirements reuse the same expression and default/unknown rules.
  (check-equal? (run (string-append required "trial = Timing.[method = \"manual\"]\nprint trial.method\n")) "manual\n")
  (check-exn #rx"does not satisfy value requirement"
             (lambda () (run (string-append required "trial = Timing.[method = \"automatic\"]\n"))))
  (check-exn #rx"missing field.*method"
             (lambda () (run (string-append required "trial = Timing.[]\n"))))
  (for ([method (in-list '("\"manual\"" "\"video\"" "\"automatic\"" "unknown"))]
        [expected (in-list '(satisfied satisfied violated violated))])
    (check-equal? (outcomes (string-append required "trial = [method = " method "]\ntrial implement Timing\n"))
                  (list expected)))
  (check-equal? (outcomes "interface Timing [must [method = unknown method in [\"manual\" \"video\"]]]\ntrial = [method = unknown]\ntrial implement Timing\n")
                '(violated))
  (check-equal? (outcomes "interface Timing [must [method = unknown method in []]]\ntrial = [method = unknown]\ntrial implement Timing\n")
                '(violated))
  (check-equal? (outcomes "interface Timing [must [method in [unknown \"manual\"]]]\ntrial = [method = \"manual\"]\ntrial implement Timing\n")
                '(satisfied))
  (check-equal? (outcomes "interface Timing [must [method in [unknown \"manual\"]]]\ntrial = [method = \"video\"]\ntrial implement Timing\n")
                '(violated))
  (check-equal? (run "interface Timing [must [methods = [\"manual\" \"video\"] method in methods]]\ntrial = Timing.[method = \"video\"]\nprint trial.method\n")
                "video\n")
  (check-equal? (outcomes "interface Timing [must [method in methods]]\ntrial = [method = \"manual\" methods = [unknown \"manual\"]]\ntrial implement Timing\n")
                '(satisfied))
  (check-equal? (outcomes "interface Timing [must [methods = unknown method in methods]]\ntrial = [method = \"manual\" methods = unknown]\ntrial implement Timing\n")
                '(undetermined))
  (check-equal? (outcomes "interface Timing [must [method in methods]]\ntrial = [method = \"manual\"]\ntrial implement Timing\n")
                '(violated))
  (check-equal? (run "interface Timing [must [method] if method in [\"manual\" \"video\"] [must [observer]] else [must [instrument]]]\ntrial = Timing.[method = \"video\" observer = \"researcher\"]\nprint trial.method\n")
                "video\n")
  (check-equal? (outcomes "interface Nested [must [timing [must [method in [\"manual\" \"video\"]]]]]\ntrial = [timing = [method = \"manual\"]]\ntrial implement Nested\n")
                '(satisfied))
  (check-equal? (outcomes "interface Series [for each trial in trials [must [trial.method in [\"manual\" \"video\"]]]]\nseries = [trials = [[method = \"manual\"] [method = \"other\"]]]\nseries implement Series\n")
                '(violated))
  (check-equal? (run (string-append required "interface Inherited [extends Timing]\ntrial = Inherited.[method = \"video\"]\nprint trial.method\n"))
                "video\n")

  (with-source
    (string-append "performer researcher [kind = \"human\"]\nto keep :value [output :value]\n"
                   "stage Choose by researcher from state [information = [method = \"manual\" methods = [\"manual\" \"video\"]]]\n"
                   "if information.method in information.methods [do keep with [value at information.method] into information.method]\n"
                   "end stage with state [information = [method = \"manual\" methods = [\"manual\" \"video\"]]]\n")
    (lambda (file) (check-not-exn (lambda () (read-workflow-model file)))))

  (with-source (string-append required "stage Measure\nMeasure implement Timing\n")
    (lambda (file)
      (define model (read-workflow-model file))
      (define interface (mapping-model-interface (first (workflow-model-mappings model))))
      (define requirements
        (filter (lambda (condition) (eq? (condition-model-kind condition) 'value-requirement))
                (interface-model-conditions interface)))
      (check-equal? (map condition-model-evidence requirements)
                    '((compare in ((result method) (list ((literal "manual") (literal "video")))))))
      (check-equal? (map condition-check-outcome (assessment-checks (assess-workflow model)))
                    '(satisfied undetermined))))

  (define directory (make-temporary-file "sciencelogo-membership-library-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (display-to-file (string-append "#lang sciencelogo\nlibrary timing [" required
                                      "to accepted :method [output :method in [\"manual\" \"video\"]]]\n")
                       (build-path directory "library.rkt"))
      (display-to-file (string-append "#lang sciencelogo\n" required) (build-path directory "timing.rkt"))
      (define (git . args)
        (unless (zero? (parameterize ([current-output-port (open-output-string)]
                                     [current-error-port (open-output-string)])
                         (apply system*/exit-code (find-executable-path "git") "-C" (path->string directory) args)))
          (error 'membership-library "Git failed")))
      (git "init" "--initial-branch=main")
      (git "add" "library.rkt" "timing.rkt")
      (git "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid" "commit" "--quiet" "-m" "Describe accepted methods")
      (git "tag" "v1")
      (define body (format "import ~s at \"v1\" as timing\ndo timing.accepted \"video\" as accepted\nprint accepted\ntrial = timing.Timing.[method = \"manual\"]\ntrial implement timing.Timing\n"
                            (format "file://~a" directory)))
      (check-equal? (run body) "true\n")
      (check-equal? (outcomes body) '(satisfied))
      (define file (build-path directory "workflow.rkt"))
      (display-to-file "#lang sciencelogo\ntrial = [method = \"manual\"]\ntrial implement \"timing.rkt\"\n" file)
      (check-equal? (map condition-check-outcome (assessment-checks (assess-file file))) '(satisfied)))
    (lambda () (delete-directory/files directory)))
  (check-equal? (with-output-to-string (lambda () (dynamic-require example #f))) "manual\n")
  (check-equal? (assessment-findings (assess-file example)) '()))
