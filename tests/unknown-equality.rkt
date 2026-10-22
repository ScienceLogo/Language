#lang racket/base

(require rackunit racket/file racket/list racket/port racket/runtime-path
         "../assessor.rkt" "../workflow-model.rkt")

(define-runtime-path example "../examples/unknown-equality.rkt")
(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-equality-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"Unknown values\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))
(define (run body)
  (with-source body (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))
(define (outcomes body)
  (with-source body (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))

(module+ test
  ;; Runtime equality and structural checks use the same value semantics.
  (for ([expression (in-list '("unknown == unknown" "unknown != 2" "2 != unknown"
                              "[unknown 2] == [unknown 2]"
                              "[period = unknown unit = \"seconds\"] == [unit = \"seconds\" period = unknown]"
                              "[value = unknown] != [value = 2]"
                              "(unknown u []) == unknown"
                              "(unknown + 2) == unknown" "(- unknown) == unknown"
                              "unknown == (unknown < 2)" "unknown == (unknown is number)"
                              "(unknown and true) == unknown" "(unknown or false) == unknown"
                              "(unknown xor false) == unknown" "(not unknown) == unknown"
                              "unknown == (2 in unknown)"))])
    (check-equal? (run (string-append "print " expression "\n")) "true\n")
    (check-equal? (outcomes (string-append "interface Equal [must [" expression "]]\n"
                                          "trial = [note = \"comparison\"]\ntrial implement Equal\n"))
                  '(satisfied)))
  (for ([expression (in-list '("unknown != unknown" "unknown == 2" "2 == unknown"
                              "unknown == false" "unknown == \"unknown\""
                              "[unknown 2] == [2 unknown]" "[value = unknown] == [value = 2]"))])
    (check-equal? (run (string-append "print " expression "\n")) "false\n")
    (check-equal? (outcomes (string-append "interface Equal [must [" expression "]]\n"
                                          "trial = [note = \"comparison\"]\ntrial implement Equal\n"))
                  '(violated)))
  (for ([expression (in-list '("unknown < 2" "2 > unknown" "unknown + 2" "unknown is number"))])
    (check-equal? (run (string-append "print " expression "\n")) "unknown\n"))
  (check-equal? (run "period = unknown\nif period == unknown [print \"pending\"] else [print period]\nperiod = 2\nif period != unknown [print period]\nto absent :value [output :value == unknown]\ndo absent unknown as answer\nprint answer\n")
                "pending\n2\ntrue\n")
  (check-equal? (run "period = unknown\nwhile period == unknown [period = 2]\nprint period\nrepeat [period = unknown] until period == unknown\nfor each value in [2 unknown] [print value == unknown]\n")
                "2\nfalse\ntrue\n")
  (check-equal? (run "print unknown in [unknown]\nprint 2 in [unknown 1]\nprint unknown in [1 2]\nprint [value = unknown] in [[value = unknown]]\n")
                "true\nfalse\nfalse\ntrue\n")

  (define plan
    (string-append "interface Plan [must [period = unknown number] "
                   "if period == unknown [must [reason]] else [must [period > 0]]]\n"))
  (check-not-exn (lambda () (run (string-append plan "trial = Plan.[reason = \"not yet measured\"]\n"))))
  (check-exn #rx"missing field.*reason" (lambda () (run (string-append plan "trial = Plan.[]\n"))))
  (check-equal? (outcomes (string-append plan "trial = [period = unknown reason = \"not yet measured\"]\ntrial implement Plan\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append plan "trial = [period = 2]\ntrial implement Plan\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append plan "trial = [period = 0]\ntrial implement Plan\n"))
                '(violated))

  ;; A checker lacking a result must not invent an explicit unknown value.
  (define equality "interface Pending [must [period = unknown period == unknown]]\n")
  (check-equal? (outcomes (string-append equality "trial = [period = unknown]\ntrial implement Pending\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append equality "to choose [output unknown]\ndo choose as value\ntrial = [period = value]\ntrial implement Pending\n"))
                '(undetermined))
  (check-equal? (outcomes "interface Known [must [period = unknown period != unknown]]\nto choose [output 2]\ndo choose as value\ntrial = [period = value]\ntrial implement Known\n")
                '(undetermined))
  (check-equal? (outcomes "interface Equal [must [left right left == right]]\nto choose [output 2]\ndo choose as value\ntrial = [left = [period = value] right = [period = value]]\ntrial implement Equal\n")
                '(undetermined))
  (check-equal? (outcomes "interface Member [must [value in candidates]]\nto choose [output 2]\ndo choose as candidate\ntrial = [value = 2 candidates = [candidate 1]]\ntrial implement Member\n")
                '(undetermined))
  (check-equal? (outcomes "interface Series [for each item in trials [must [item.period]]]\nto choose [output [period = 2]]\ndo choose as value\nseries = [trials = [value]]\nseries implement Series\n")
                '(undetermined))
  (check-equal? (outcomes "interface Pending [period if period == unknown [must [reason]]]\ntrial = [note = \"no period field\"]\ntrial implement Pending\n")
                '(undetermined))
  (check-equal? (outcomes "interface Strict [must [period] if period == unknown [must [reason]]]\ntrial = [period = unknown reason = \"not measured\"]\ntrial implement Strict\n")
                '(violated))
  (with-source "must do target\nif [value = unknown] == [value = unknown] [do target]\nto target []\n"
    (lambda (file)
      (check-equal? (map condition-check-outcome (assessment-checks (assess-file file))) '(satisfied))))
  (with-source "must do target\nif unknown == 2 [do target]\nto target []\n"
    (lambda (file)
      (check-equal? (map condition-check-outcome (assessment-checks (assess-file file))) '(violated))))
  (with-source "interface Pending [must [period = unknown] if period == unknown [must [reason]]]\nstage Plan\nPlan implement Pending\n"
    (lambda (file)
      (define model (read-workflow-model file))
      (define interface (mapping-model-interface (first (workflow-model-mappings model))))
      (define reason (findf (lambda (condition) (eq? (condition-model-target condition) 'reason))
                            (interface-model-conditions interface)))
      (check-equal? (condition-model-guard reason) '(compare == ((result period) (literal unknown))))))
  (check-equal? (with-output-to-string (lambda () (dynamic-require example #f))) "")
  (check-equal? (assessment-findings (assess-file example)) '()))
