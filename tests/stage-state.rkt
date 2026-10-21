#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/string
         "../assessor.rkt"
         "../private/reader.rkt"
         "../workflow-model.rkt")

(define prefix
  (string-append
   "#lang sciencelogo\n"
   "to calculate-period :duration :count [output :duration / :count]\n"
   "performer researcher [kind = \"human\" role = \"scientist\"]\n"
   "stage \"Analyze\" by researcher from state [information = [elapsed = unknown swing-count = 10]]\n"))

(define suffix
  "end stage with state [information = [elapsed = unknown swing-count = 10 period = unknown]]\n")

(define (with-method source use)
  (define path (make-temporary-file "sciencelogo-state-~a.rkt"))
  (dynamic-wind
    (lambda ()
      (call-with-output-file path
        (lambda (out) (display source out)) #:exists 'truncate))
    (lambda () (use path))
    (lambda () (delete-file path))))

(define (read-method source)
  (with-method source parse-sciencelogo-file))

(define (reject pattern source)
  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? pattern (exn-message e))))
   (lambda () (read-method source))))

(define valid-call
  (string-append
   "do calculate-period with [\n"
   "  duration at information.elapsed\n"
   "  count at information.swing-count\n"
   "] into information.period\n"))

(define valid-source (string-append prefix valid-call suffix))

(check-equal?
 (let ([method (read-method valid-source)])
   (define stage (third (third method)))
   (list (first stage) (second stage)
         (first (first (fourth stage)))))
 '(state-stage "Analyze" state-call))

(with-method valid-source
  (lambda (path)
    (define method (read-workflow-model path))
    (check-equal? (map stage-model-name (workflow-model-stages method))
                  '("Analyze"))
    (check-not-false (stage-model-entry (first (workflow-model-stages method))))
    (check-not-false (stage-model-exit (first (workflow-model-stages method))))
    (check-not-false
     (member 'state-call
             (map activity-model-kind (workflow-model-activities method))))
    (check-equal?
     (take (activity-model-details
      (first (filter (lambda (activity)
                       (eq? (activity-model-kind activity) 'state-call))
                     (workflow-model-activities method)))) 3)
     '(((duration (information elapsed)) (count (information swing-count)))
       (information period) researcher))
    (check-equal? (stage-model-performer (first (workflow-model-stages method)))
                  'researcher)
    (check-equal? (map performer-model-name (workflow-model-performers method))
                  '(researcher))))

(with-method
 (string-append
  "#lang sciencelogo\n"
  "performer researcher [kind = \"human\"]\n"
  "performer assistant [kind = \"AI\" role = \"suggest explanations\"]\n"
  "to ready [output true]\n"
  "stage \"Check\" by researcher from state [information = []]\n"
  "do ready by assistant into information.suggestion\n"
  "end stage with state [information = [suggestion = unknown]]\n")
 (lambda (path)
   (define method (read-workflow-model path))
   (define call
     (first (filter (lambda (activity)
                      (eq? (activity-model-kind activity) 'state-call))
                    (workflow-model-activities method))))
   (define assistant
     (second (workflow-model-performers method)))
   (check-equal? (third (activity-model-details call)) 'assistant)
   (check-equal? (performer-model-fields assistant)
                 '(fields ((kind (literal "AI"))
                           (role (literal "suggest explanations")))))
   (check-true
    (for/or ([relation (in-list (workflow-model-relations method))])
      (and (eq? (relation-model-kind relation) 'performed-by)
           (equal? (relation-model-from relation) (activity-model-id call))
           (equal? (relation-model-to relation) (performer-model-id assistant)))))))

(check-not-false
 (read-method
  (string-append
   "#lang sciencelogo\n"
   "to ready [output true]\n"
   "stage \"Check\" from state [information = []]\n"
   "do ready by checker into information.ready\n"
   "end stage with state [information = [ready = unknown]]\n"
   "performer checker []\n")))

(reject #rx"state-changing call needs a performer"
        (string-replace valid-source "by researcher " ""))
(reject #rx"unknown performer missing"
        (string-replace valid-source "by researcher" "by missing"))
(reject #rx"duplicate performer researcher"
        (string-append "#lang sciencelogo\n"
                       "performer researcher []\nperformer researcher []\n"))
(reject #rx"performer needs named fields"
        "#lang sciencelogo\nperformer researcher [\"scientist\"]\n")
(reject #rx"expected a performer name"
        (string-replace valid-source "by researcher" "by \"scientist\""))

(with-method
 (string-append
  "#lang sciencelogo\n"
  "must do calculate-period\n"
  "must stages in order [\"Prepare\" \"Analyze\"]\n"
  "stage \"Prepare\" from state []\n"
  "end stage with state []\n"
  (substring prefix (string-length "#lang sciencelogo\n"))
  valid-call suffix)
 (lambda (path)
   (define result (assess-file path))
   (check-equal? (map condition-check-outcome (assessment-checks result))
                 '(satisfied satisfied))
   (check-equal? (assessment-findings result) '())))

(check-not-false
 (read-method
  (string-append
   "#lang sciencelogo\n"
   "to ready [output true]\n"
   "performer checker []\n"
   "stage \"Check\" by checker from state [information = []]\n"
   "do ready into information.ready\n"
   "end stage with state [information = [ready = unknown]]\n")))

(reject #rx"duplicate input mapping"
        (string-append prefix
                       "do calculate-period with [duration at information.elapsed "
                       "duration at information.swing-count] into information.period\n"
                       suffix))
(reject #rx"input mappings.*must match"
        (string-append prefix
                       "do calculate-period with [duration at information.elapsed] "
                       "into information.period\n"
                       suffix))
(reject #rx"input mappings.*must match"
        (string-append prefix
                       "do calculate-period with [duration at information.elapsed "
                       "count at information.swing-count extra at information.elapsed] "
                       "into information.period\n"
                       suffix))
(reject #rx"input location information.missing is not available"
        (string-append prefix
                       "do calculate-period with [duration at information.missing "
                       "count at information.swing-count] into information.period\n"
                       suffix))
(reject #rx"return location needs an existing parent"
        (string-append prefix
                       "do calculate-period with [duration at information.elapsed "
                       "count at information.swing-count] into environment.period\n"
                       suffix))
(reject #rx"closing state omits information.period"
        (string-append prefix valid-call
                       "end stage with state [information = [elapsed = unknown "
                       "swing-count = 10]]\n"))
(reject #rx"closing state adds information.unexplained"
        (string-append prefix valid-call
                       "end stage with state [information = [elapsed = unknown "
                       "swing-count = 10 period = unknown unexplained = true]]\n"))
(reject #rx"closing state changes information.swing-count"
        (string-append
         "#lang sciencelogo\n"
         "stage \"Analyze\" from state [information = [swing-count = 10]]\n"
         "end stage with state [information = [swing-count = 9]]\n"))
(reject #rx"only for integer counters or positions"
        (string-append prefix
                       "observation = \"shorter\"\n"
                       valid-call suffix))
(check-not-false
 (read-method
  (string-append prefix
                 "position = 1\n"
                 "position = position + 1\n"
                 valid-call suffix)))
(reject #rx"closing state adds information.period"
        (string-append prefix
                       "if unknown [" valid-call "]\n"
                       suffix))
(check-not-false
 (read-method
  (string-append prefix
                 "if unknown [" valid-call "] else [" valid-call "]\n"
                 suffix)))
(reject #rx"may finish without output"
        (string-append
         "#lang sciencelogo\n"
         "to maybe :duration :count [if true [output :duration / :count]]\n"
         "performer researcher []\n"
         "stage \"Analyze\" by researcher from state [information = [elapsed = 2 count = 1]]\n"
         "do maybe with [duration at information.elapsed count at information.count] "
         "into information.period\n"
         "end stage with state [information = [elapsed = 2 count = 1 period = unknown]]\n"))
(reject #rx"calls inside a state stage need with locations"
        (string-append prefix
                       "do calculate-period 2 10 as period\n"
                       suffix))
(reject #rx"belongs inside a state stage"
        (string-append
         "#lang sciencelogo\n"
         "to ready [output true]\n"
         "do ready into information.ready\n"))
(reject #rx"needs end stage with state"
        (string-append prefix valid-call))
(reject #rx"end stage has no matching stage"
        "#lang sciencelogo\nend stage with state []\n")

(check-equal?
 (let ([method (read-method "#lang sciencelogo\nstage \"Old\"\n")])
   (first (third method)))
 '(stage "Old"))

(check-not-false
 (read-method
  (string-append
   "#lang sciencelogo\n"
   "to ready [output 3]\n"
   "performer researcher []\n"
   "stage \"Check\" by researcher from state [information = [trials = [1 2]]]\n"
   "for each position in [1 2] [do ready into information.trials.[position]]\n"
   "end stage with state [information = [trials = [1 2]]]\n")))

(check-not-false
 (read-method
  (string-append
   "#lang sciencelogo\n"
   "stage \"Check\" from state [information.clock.time = \"12:00\"]\n"
   "end stage with state [information.clock.time = \"12:00\"]\n")))
