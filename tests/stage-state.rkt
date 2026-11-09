#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/port
         racket/string
         "../assessor.rkt"
         "../private/reader.rkt"
         "../workflow-model.rkt")

(define prefix
  (string-append
   "#lang sciencelogo\n"
   "to calculate-period :duration :count [output :duration / :count]\n"
   "performer researcher [kind = \"human\" role = \"scientist\"]\n"
   "stage Analyze by researcher from state [information = [elapsed = unknown swing-count = 10]]\n"))

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
  "stage Check by researcher from state [information = []]\n"
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
   "stage Check from state [information = []]\n"
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
  "must stages in order [Prepare Analyze]\n"
  "stage Prepare from state []\n"
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
   "stage Check by checker from state [information = []]\n"
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
         "stage Analyze from state [information = [swing-count = 10]]\n"
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
         "stage Analyze by researcher from state [information = [elapsed = 2 count = 1]]\n"
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
 (let ([method (read-method "#lang sciencelogo\nstage Old\n")])
   (first (third method)))
 '(stage "Old"))

(check-not-false
 (read-method
  (string-append
   "#lang sciencelogo\n"
   "to ready [output 3]\n"
   "performer researcher []\n"
   "stage Check by researcher from state [information = [trials = [1 2]]]\n"
   "for each position in [1 2] [do ready into information.trials.[position]]\n"
   "end stage with state [information = [trials = [1 2]]]\n")))

(check-not-false
 (read-method
  (string-append
   "#lang sciencelogo\n"
   "stage Check from state [information.clock.time = \"12:00\"]\n"
   "end stage with state [information.clock.time = \"12:00\"]\n")))

;; Phases group workflow-level stages and smaller phases, with an optional
;; description. They are declarations: nothing runs and no order is imposed.
(module+ test
  (define stages "stage Setup\nprint 1\nstage Timing\nprint 2\nstage Report\nprint 3\n")
  (define phased
    (string-append
     "#lang sciencelogo\n" stages
     "phase Measurement\nabout \"Measure the period.\"\n[Setup Timing]\n"
     "phase Study contains Measurement and Report\n"))
  (with-method phased
    (lambda (path)
      (check-equal? (with-output-to-string (lambda () (dynamic-require path #f))) "1\n2\n3\n")
      (define model (read-workflow-model path))
      (define phases (workflow-model-phases model))
      (define stage-id
        (for/hash ([stage (in-list (workflow-model-stages model))])
          (values (stage-model-name stage) (stage-model-id stage))))
      (define measurement (first phases))
      (define study (second phases))
      (check-equal? (map phase-model-name phases) '("Measurement" "Study"))
      (check-equal? (phase-model-members measurement)
                    (list (hash-ref stage-id "Setup") (hash-ref stage-id "Timing")))
      (check-equal? (phase-model-members study)
                    (list (phase-model-id measurement) (hash-ref stage-id "Report")))
      (check-equal? (phase-model-parent measurement) (phase-model-id study))
      (check-false (phase-model-parent study))
      (check-equal? (description-model-text (phase-model-description measurement))
                    "Measure the period.")
      (check-false (phase-model-description study))
      (check-equal? (source-ref-line (phase-model-source measurement)) 8)
      (check-equal? (map (lambda (ref) (list (source-ref-line ref) (source-ref-column ref)))
                         (map phase-model-end phases))
                    '((10 14) (11 43)))
      (check-not-false
       (for/or ([relation (in-list (workflow-model-relations model))])
         (and (eq? (relation-model-kind relation) 'groups)
              (equal? (relation-model-from relation) (phase-model-id study))
              (equal? (relation-model-to relation) (phase-model-id measurement)))))
      (check-equal? (assessment-findings (assess-file path)) '())
      (check-equal? (list-ref (third (parse-sciencelogo-file path)) 6)
                    '(phase "Measurement" ("Setup" "Timing") ((about "Measure the period."))))))

  ;; A phase may follow or precede its stages and may sit in an included file.
  (with-method (string-append "#lang sciencelogo\nphase Early [Setup]\n" stages)
    (lambda (path)
      (check-equal? (map phase-model-name (workflow-model-phases (read-workflow-model path)))
                    '("Early"))))

  (define (phase-error body)
    (with-method (string-append "#lang sciencelogo\n" stages body)
      (lambda (path)
        (with-handlers ([exn:fail:read? exn-message])
          (parse-sciencelogo-file path)
          #f))))
  (check-regexp-match #rx"lists Setup after Timing" (phase-error "phase P [Timing Setup]\n"))
  (check-regexp-match #rx"not continuous: stage Timing lies between Setup and Report"
                      (phase-error "phase P [Setup Report]\n"))
  (check-regexp-match #rx"Timing already belongs to phase P"
                      (phase-error "phase P [Setup Timing]\nphase Q [Timing Report]\n"))
  (check-regexp-match #rx"phase cycle" (phase-error "phase P [Q]\nphase Q [P]\n"))
  (check-regexp-match #rx"unknown stage or phase Missing" (phase-error "phase P [Missing]\n"))
  (check-regexp-match #rx"needs at least one" (phase-error "phase P []\n"))
  (check-regexp-match #rx"lists Setup twice" (phase-error "phase P [Setup Setup]\n"))
  (check-regexp-match #rx"phase name Setup conflicts with a stage" (phase-error "phase Setup [Timing]\n"))
  (check-regexp-match #rx"duplicate phase P" (phase-error "phase P [Setup]\nphase P [Report]\n"))
  (check-regexp-match #rx"only workflow-level stages; Inner is inside"
                      (phase-error "to plan [stage Inner print 4]\ndo plan\nphase P [Inner]\n"))
  (check-regexp-match #rx"phase belongs directly in a workflow" (phase-error "do [phase P [Setup]]\n"))
  (check-regexp-match #rx"phase belongs directly in a workflow"
                      (phase-error "to plan [phase P [Setup]]\n")))

;; Stages, phases, and procedures record where they end in their file.
(module+ test
  (define (span ref) (list (source-ref-line ref) (source-ref-column ref)))
  (with-method
    (string-append
     "#lang sciencelogo\n"
     "to period :duration :swings\nabout \"Divide.\"\n[\n  output :duration / :swings\n]\n"
     "stage First\nx = 2\nto helper [print 1]\nprint x ; a trailing comment\n"
     "performer researcher []\n"
     "start stage Paired by researcher from state [information = []]\n"
     "end stage with state [information = []]\n"
     "stage Last\n")
    (lambda (path)
      (define model (read-workflow-model path))
      (define procedure (first (workflow-model-procedures model)))
      (check-equal? (span (procedure-model-source procedure)) '(2 0))
      (check-equal? (span (procedure-model-end procedure)) '(6 1))
      (define stages (workflow-model-stages model))
      (check-equal? (map stage-model-name stages) '("First" "Paired" "Last"))
      ;; A verbose stage starts at start; a simple stage's section ends with
      ;; its last command, and an empty one at its header.
      (check-equal? (map (lambda (stage) (span (stage-model-source stage))) stages)
                    '((7 0) (12 0) (14 0)))
      (check-equal? (map (lambda (stage) (span (stage-model-end stage))) stages)
                    '((10 7) (13 39) (14 10)))
      (check-equal? (span (procedure-model-end (second (workflow-model-procedures model))))
                    '(9 19))))
  (with-method "#lang sciencelogo\nto plan\nabout \"x\"\n[print 1]\ndo plan\n"
    (lambda (path)
      (check-equal? (description-model-text
                     (procedure-model-description (first (workflow-model-procedures (read-workflow-model path)))))
                    "x"))))
