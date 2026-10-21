#lang racket/base

(require rackunit racket/file racket/list racket/match racket/port
         "../private/reader.rkt" "../workflow-model.rkt" "../assessor.rkt")

(define (with-source body use)
  (define path (make-temporary-file "sciencelogo-groups-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\n" body) path #:exists 'truncate))
    (lambda () (use path))
    (lambda () (delete-file path))))
(define (run body)
  (with-source body (lambda (path) (with-output-to-string (lambda () (dynamic-require path #f))))))
(define (outcomes body)
  (with-source body (lambda (path) (map condition-check-outcome (assessment-checks (assess-file path))))))

(module+ test
  ;; Grouped comparisons are values; ungrouped comparison chains stay invalid.
  (check-equal? (run "print ((1 == 1)) == true\nprint true == (1 == 1)\nprint (2 is number) == true\nprint ((true)) == ((1 < 2))\n")
                "true\ntrue\ntrue\ntrue\n")
  (for ([expression '("1 < 2 < 3" "2 is number == true" "(1 == 1) == true == true")])
    (check-exn #rx"comparison cannot be chained" (lambda () (run (string-append "print " expression)))))
  (check-equal? (run "print ((1 + 2) * 3)\nprint (1 + (2 * 3))\nprint not ((1 == 1) and (false))\n")
                "9\n7\ntrue\n")
  (check-equal? (run "items = ([1 (2) ((3))])\ntrial = ([temperature = (0.8) note = (\"timed\")])\nprint ((trial)).temperature\nprint items.[(1 + 1)]\nprint trial.[(temperature) (note)]\nprint ((note)) in (trial)\n")
                "0.8\n2\n[note = \"timed\" temperature = 0.8]\ntrue\n")
  (check-equal? (run "to identity :value [output ((:value))]\ndo identity (((3))) as result\nprint result\nrepeat (2) [print (true)]\n")
                "3\ntrue\ntrue\n")

  ;; The serialized tree and public workflow model keep each pair of parentheses.
  (with-source
   "value = ((2))\nprint (((value)))\n"
   (lambda (path)
     (check-equal? (parse-sciencelogo-file path)
                   '(workflow #f ((assignment value (group (group (literal 2))))
                                  (print (group (group (group (result value))))))))
     (define method (read-workflow-model path))
     (check-equal? (map activity-model-details (workflow-model-activities method))
                   '((assignment value (group (group (literal 2))))
                     (print (group (group (group (result value)))))))
     (check-not-false
      (findf (lambda (relation) (eq? (relation-model-kind relation) 'uses))
             (workflow-model-relations method)))
     (define tree (parse-sciencelogo-tree-file path))
     (define group (cdr (node-value (first (node-children tree)))))
     (check-equal? (node-kind group) 'group)
     (check-equal? (token-column (node-at group)) 8)
     (check-equal? (token-column (node-at (first (node-children group)))) 9)))

  (define shape
    (string-append
     "interface \"timing_shape\" [must [period = (unknown) number unit = (\"seconds\") ((period == unknown) or (period > 0))]]\n"
     "trial = (timing_shape.[])\ntrial implement timing_shape\n"))
  (check-equal? (run (string-append shape "print trial.period\nprint trial.unit\n")) "unknown\nseconds\n")
  (check-equal? (outcomes shape) '(satisfied))
  (check-equal?
   (run "interface \"First\" [must [unit = (\"seconds\")]]\ninterface \"Second\" [must [unit = \"seconds\"]]\ninterface \"Combined\" [extends First extends Second]\ntrial = Combined.[]\nprint trial.unit\n")
   "seconds\n")
  (check-equal?
   (outcomes "interface \"Series\" [must [measurements] for each item in measurements [must [item.period > 0]]]\ntrial = [measurements = [[period = 1]]]\ntrial.measurements.[((1))].period = (2)\ntrial implement Series\n")
   '(satisfied))
  (check-equal?
   (outcomes "interface \"Trial\" [must [details] if ((notes)) in ((details)) [must [reviewer]]]\ntrial = ([details = ([notes = unknown]) reviewer = (\"human\")])\ntrial implement Trial\n")
   '(satisfied))
  (check-equal?
   (run "interface \"Series\" [must [measurements] for each measurement in (measurements) [must [(measurement.period > 0) measurement.unit = (\"seconds\")]]]\nseries = Series.[measurements = ([( [period = (2)] )])]\nprint series.measurements.[1].unit\n")
   "seconds\n")
  (check-equal? (run "period = (2) u ([declared = ([timing = ([estimate = (0.1)])])])\nprint ((period)).u.declared.timing.estimate\n") "0.1\n")
  (check-exn #rx"only one u description" (lambda () (run "value = (2 u []) u []")))
  (check-equal? (run "conclusions += (conclusion finding [text = (\"A finding\")])\nprint conclusions.finding.text\n") "A finding\n")

  ;; Structural call checks see grouped controls without claiming execution.
  (check-equal? (outcomes "must do check\nif ((true)) [repeat (1) [do check]]\nto check []\n") '(satisfied))
  (check-equal? (outcomes "must do check\nfor each index in ([1]) [do check]\nto check []\n") '(satisfied))

  ;; Grouping at either state boundary does not invent a value change. Location
  ;; syntax is retained beside the resolved paths, including grouped positions.
  (define staged
    (string-append
     "performer observer ([kind = (\"human\")])\n"
     "to inspect :period [repeat (1) [output ((:period))]]\n"
     "stage \"Inspect\" by observer from state ([information = ([periods = ([2 3])])])\n"
     "position = (1)\nrepeat (1) [do inspect with [period at information.periods.[(position)]] into information.periods.[((1))]]\n"
     "end stage with state [information = [periods = [2 3]]]\n"))
  (with-source staged
    (lambda (path)
      (check-not-exn (lambda () (parse-sciencelogo-file path)))
      (define method (read-workflow-model path))
      (check-match (stage-model-entry (first (workflow-model-stages method))) `(group ,_))
      (define call (findf (lambda (activity) (eq? (activity-model-kind activity) 'state-call))
                          (workflow-model-activities method)))
      (check-match (fourth (activity-model-details call))
                   `(locations ((period (location (information periods (index position))
                                         (dot-select (,(? list?) (group (result position)))))))
                               (location (information periods 1)
                                         (dot-select (,(? list?) (group (group (literal 1)))))))))))
