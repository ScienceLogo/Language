#lang racket/base

(require rackunit racket/file racket/list racket/port racket/runtime-path
         "../assessor.rkt" "../workflow-model.rkt" "../private/reader.rkt")

(define-runtime-path example "../examples/list-requirements.rkt")
(define minimum
  "interface Timing-series [must [measurements.count >= 3]]\n")
(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-count-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"Count measurements\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))
(define (run body)
  (with-source body (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))
(define (outcomes body)
  (with-source body (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))
(define (check-list value)
  (outcomes (string-append minimum "series = [measurements = " value "]\nseries implement Timing-series\n")))

(module+ test
  (check-equal? (run "trial = [count = 7]\nprint trial.count\ntrial.count = 8\ntrial.count += 1\nprint trial.count\n")
                "7\n9\n")
  (check-equal? (run "interface Trial [must [count = 7]]\ntrial = Trial.[]\nprint trial.count\ntrial.count = \"many\"\nprint trial.count\n")
                "7\nmany\n")
  (check-equal? (run "items = []\nprint items.count\nitems += unknown\nprint items.count\n") "0\n1\n")
  (check-equal? (run "print [unknown unknown 3].count\n") "3\n")
  (check-equal? (run "items = [unknown unknown] u []\nprint items.count\n") "2\n")
  (check-equal? (run "items = unknown\nprint items.count\n") "unknown\n")
  (check-equal? (run "grid = [[1 2] [3]]\nprint grid.count\nprint grid.[1].count\n") "2\n2\n")
  (check-equal? (run "items = [1 unknown 3]\nprint items.[1 2].count\n") "2\n")
  (check-equal? (run "lengths = range 0.25 to 1 step 0.25\nprint lengths.count\n") "4\n")
  (check-equal? (run "to size :items [output :items.count]\ndo size [unknown unknown] as total\nprint total\n") "2\n")
  (check-equal? (run "items = []\nwhile items.count < 3 [items += unknown]\nif items.count == 3 [print items.count]\n") "3\n")
  (check-equal? (run "items = [1 2]\nrepeat items.count [print \"trial\"]\n") "trial\ntrial\n")
  (check-equal? (run "items = [1 2]\ncopy = items\nitems += 3\nprint copy.count print items.count\n") "2\n3\n")
  (for ([body (in-list '("items = [1 2]\nitems.count = 3\n"
                        "items = [1 2]\nitems.count += 1\n"))])
    (check-exn #rx".count is read only" (lambda () (run body))))
  (check-exn #rx".count needs" (lambda () (run "print (12).count\n")))
  (check-exn #rx".count needs" (lambda () (run "print \"timing\".count\n")))

  (check-equal? (check-list "[unknown unknown unknown]") '(satisfied))
  (check-equal? (check-list "[1 2]") '(violated))
  (check-equal? (check-list "[]") '(violated))
  (check-equal? (check-list "unknown") '(violated))
  (check-equal? (check-list "range 1 to 3 step 1") '(satisfied))
  (check-equal? (outcomes (string-append minimum "series = [note = \"not measured\"]\nseries implement Timing-series\n"))
                '(violated))
  (check-equal? (run (string-append minimum
                                   "series = Timing-series.[measurements = [unknown unknown unknown]]\nprint series.measurements.count\n"))
                "3\n")
  (check-exn #rx"does not satisfy value requirement"
             (lambda () (run (string-append minimum "series = Timing-series.[measurements = [1 2]]\n"))))
  (check-exn #rx"does not satisfy value requirement"
             (lambda () (run (string-append minimum "series = Timing-series.[measurements = unknown]\n"))))
  (check-exn #rx".count is read only"
             (lambda () (run "interface Invalid [must [measurements.count = 3]]\nseries = Invalid.[measurements = [1 2 3]]\n")))
  (check-equal? (outcomes "interface Exact [must [measurements.count == 3]]\nseries = [measurements = [unknown unknown unknown]]\nseries implement Exact\n")
                '(satisfied))
  (check-equal? (outcomes "interface Nested [must [groups] for each group in groups [must [group.measurements.count >= 2]]]\nseries = [groups = [[measurements = [unknown unknown]]]]\nseries implement Nested\n")
                '(satisfied))
  (check-equal? (outcomes "interface Literal [must [[unknown unknown].count == 2]]\nseries = [note = \"plan\"]\nseries implement Literal\n")
                '(satisfied))
  (check-equal? (outcomes "interface Selected [must [measurements.[1 2].count == 2]]\nseries = [measurements = [unknown unknown unknown]]\nseries implement Selected\n")
                '(satisfied))
  (check-equal? (outcomes "interface Selected [must [measurements.[1 100].count == 2]]\nseries = [measurements = [unknown unknown unknown]]\nseries implement Selected\n")
                '(undetermined))
  (check-equal? (outcomes (string-append minimum
                                        "series = [measurements = [1 2 3]]\n"
                                        "series.measurements.[2] = unknown\nseries implement Timing-series\n"))
                '(satisfied))
  (check-equal? (run "interface Defaulted [must [measurements = [unknown unknown unknown] measurements.count >= 3]]\nseries = Defaulted.[]\nprint series.measurements.count\n")
                "3\n")
  (check-equal? (outcomes (string-append minimum
                                        "interface Reviewed [extends Timing-series must [reviewer]]\n"
                                        "series = [measurements = [unknown unknown unknown] reviewer = \"researcher\"]\nseries implement Reviewed\n"))
                '(satisfied))

  (with-source
   (string-append minimum "stage Measure\nMeasure implement Timing-series\n")
   (lambda (file)
     (define model (read-workflow-model file))
     (define interface (mapping-model-interface (first (workflow-model-mappings model))))
     (define entries (filter (lambda (condition) (eq? (condition-model-kind condition) 'required-entry))
                             (interface-model-conditions interface)))
     (check-equal? (map condition-model-target entries) '(measurements))
     (check-equal? (condition-model-evidence
                   (findf (lambda (condition) (eq? (condition-model-kind condition) 'value-requirement))
                          (interface-model-conditions interface)))
                   '(compare >= ((field-ref count (result measurements)) (literal 3))))
     (check-equal? (map condition-check-outcome (assessment-checks (assess-workflow model))) '(satisfied undetermined))))

  ;; The count is a readable state property, not a separately stored field.
  (define stage
    (string-append "performer researcher [kind = \"human\"]\n"
                   "to save-size :n [output :n]\n"
                   "stage Count by researcher from state [information = [measurements = [unknown unknown] size = 0]]\n"
                   "do save-size with [n at information.measurements.count] into information.size\n"
                   "end stage with state [information = [measurements = [unknown unknown] size = 2]]\n"))
  (with-source stage (lambda (file) (check-not-exn (lambda () (read-workflow-model file)))))
  (with-source
   (string-append "performer researcher [kind = \"human\"]\nto size [output 2]\n"
                  "stage Count by researcher from state [information = [measurements = [unknown unknown]]]\n"
                  "do size into information.measurements.count\n"
                  "end stage with state [information = [measurements = [unknown unknown]]]\n")
   (lambda (file) (check-exn #rx".count is read only" (lambda () (read-workflow-model file)))))
  (with-source
   (string-append "performer researcher [kind = \"human\"]\nto keep :value [output :value]\n"
                  "stage Count by researcher from state [information = [measurements = [unknown unknown]]]\n"
                  "positions = information.measurements.count\n"
                  "for each position in range 1 to positions step 1 ["
                  "do keep with [value at information.measurements.[position]] into information.measurements.[position]]\n"
                  "end stage with state [information = [measurements = [unknown unknown]]]\n")
   (lambda (file) (check-not-exn (lambda () (read-workflow-model file)))))

  (check-equal? (assessment-findings (assess-file example)) '()))
