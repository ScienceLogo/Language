#lang racket/base

(require racket/list
         racket/match
         "../workflow-model.rkt"
         "constant-values.rkt")

(provide required-call-paths)

;; This is a conservative check of the written method, not a run trace.
;; Values obtained from inputs, named results, and assignments are unknown here.
(struct path-state (called? flow evidence) #:transparent)

(define (condition-status expression)
  (define value (constant-value expression))
  (cond [(eq? value #t) 'true]
        [(eq? value #f) 'false]
        [else 'unknown]))

(define (count-status expression)
  (define value (constant-value expression))
  (cond [(and (exact-nonnegative-integer? value) (zero? value)) 'empty]
        [(exact-nonnegative-integer? value) 'nonempty]
        [else 'unknown]))

(define (collection-status expression)
  (match expression
    [`(list ,parts) (if (null? parts) 'empty 'nonempty)]
    [`(range (,start ,end ,step))
     (define a (constant-value start))
     (define b (constant-value end))
     (define delta (constant-value step))
     (if (and (real? a) (exact? a)
              (real? b) (exact? b)
              (real? delta) (exact? delta)
              (not (zero? delta))
              (or (= a b)
                  (and (< a b) (positive? delta))
                  (and (> a b) (negative? delta))))
         'nonempty
         'unknown)]
    [_ 'unknown]))

(define (merge-states states)
  (define keys '())
  (define grouped (make-hash))
  (for ([state (in-list states)])
    (define key (cons (path-state-called? state) (path-state-flow state)))
    (unless (hash-has-key? grouped key)
      (set! keys (cons key keys))
      (hash-set! grouped key '()))
    (hash-set! grouped key
               (append (hash-ref grouped key) (path-state-evidence state))))
  (for/list ([key (in-list (reverse keys))])
    (path-state (car key) (cdr key)
                (remove-duplicates (hash-ref grouped key)))))

(define (required-call-paths method target)
  (define children (make-hash))
  (define (add-child parent element)
    (hash-update! children parent (lambda (xs) (cons element xs)) '()))
  (for ([stage (in-list (workflow-model-stages method))])
    (add-child (stage-model-parent stage) stage))
  (for ([activity (in-list (workflow-model-activities method))])
    (add-child (activity-model-parent activity) activity))
  (define (element-id element)
    (if (stage-model? element)
        (stage-model-id element)
        (activity-model-id element)))
  (define (element-position element)
    (source-ref-position
     (if (stage-model? element)
         (stage-model-source element)
         (activity-model-source element))))
  (define (steps parent)
    (append*
     (for/list ([element (in-list
                          (sort (hash-ref children parent '()) <
                                #:key element-position))])
       (if (stage-model? element)
           (steps (element-id element))
           (list element)))))
  (define invoked (make-hash))
  (for ([relation (in-list (workflow-model-relations method))]
        #:when (eq? (relation-model-kind relation) 'invokes))
    (hash-set! invoked (relation-model-from relation)
               (relation-model-to relation)))
  (define (blocked state)
    (struct-copy path-state state [flow 'blocked]))
  (define (returning state)
    (struct-copy path-state state [flow 'return]))
  (define (analyze-block parent states active)
    (for/fold ([current states]) ([step (in-list (steps parent))])
      (merge-states
       (append*
        (for/list ([state (in-list current)])
          (if (eq? (path-state-flow state) 'continue)
              (analyze-step step state active)
              (list state)))))))
  (define (analyze-branches branches state active)
    (cond
      [(null? branches) (list state)]
      [else
       (define branch (car branches))
       (define condition (activity-model-control branch))
       (define status (if condition (condition-status condition) 'true))
       (case status
         [(true)
          (analyze-block (activity-model-id branch) (list state) active)]
         [(false) (analyze-branches (cdr branches) state active)]
         [else
          (append (analyze-block (activity-model-id branch) (list state) active)
                  (analyze-branches (cdr branches) state active)
                  (list (struct-copy path-state state [flow 'unresolved])))])]))
  (define (analyze-loop-body activity state active exit-status)
    (define after
      (analyze-block (activity-model-id activity) (list state) active))
    (append*
     (for/list ([body-state (in-list after)])
       (if (not (eq? (path-state-flow body-state) 'continue))
           (list body-state)
           (case exit-status
             [(true) (list body-state)]
             [(false) (list (blocked body-state))]
             [else (list body-state (blocked body-state)
                         (struct-copy path-state body-state
                                      [flow 'unresolved]))])))))
  (define (analyze-step activity state active)
    (define id (activity-model-id activity))
    (define control (activity-model-control activity))
    (case (activity-model-kind activity)
      [(call state-call)
       (define procedure (hash-ref invoked id #f))
       (define entered
         (if (equal? procedure target)
             (struct-copy path-state state
                          [called? #t]
                          [evidence (cons id (path-state-evidence state))])
             state))
       (cond
         [(not procedure) (list entered)]
         [(member procedure active) (list (blocked entered))]
         [else
          (for/list ([result (in-list
                              (analyze-block procedure (list entered)
                                             (cons procedure active)))])
            (if (memq (path-state-flow result) '(blocked unresolved))
                result
                (struct-copy path-state result [flow 'continue])))])]
      [(output) (list (returning state))]
      [(sequence) (analyze-block id (list state) active)]
      [(if)
       (analyze-branches
        (filter activity-model?
                (sort (hash-ref children id '()) < #:key element-position))
        state active)]
      [(repeat)
       (case (count-status control)
         [(empty) (list state)]
         [(nonempty) (analyze-block id (list state) active)]
         [else (append (list state
                             (struct-copy path-state state [flow 'unresolved]))
                       (analyze-block id (list state) active))])]
      [(for-each)
       (case (collection-status control)
         [(empty) (list state)]
         [(nonempty) (analyze-block id (list state) active)]
         [else (append (list state
                             (struct-copy path-state state [flow 'unresolved]))
                       (analyze-block id (list state) active))])]
      [(while)
       (case (condition-status control)
         [(false) (list state)]
         [(true) (analyze-loop-body activity state active 'false)]
         [else (append (list state
                             (struct-copy path-state state [flow 'unresolved]))
                       (analyze-loop-body activity state active 'unknown))])]
      [(repeat-until)
       (analyze-loop-body activity state active
                          (condition-status control))]
      [else (list state)]))
  (define final
    (analyze-block (workflow-model-id method)
                   (list (path-state #f 'continue '())) '()))
  (define calls
    (remove-duplicates (append* (map path-state-evidence final))))
  (values (cond [(andmap path-state-called? final) 'satisfied]
                [(pair? calls) 'undetermined]
                [else 'violated])
          calls))
