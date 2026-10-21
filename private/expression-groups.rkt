#lang racket/base

(require racket/match)

(provide ungroup-expression expression-equivalent?)

;; Inspect a value expression without altering its recorded syntax. Every
;; source parenthesis remains a (group expression) in the reader and model.
(define (ungroup-expression expression)
  (match expression
    [`(group ,inner) (ungroup-expression inner)]
    [_ expression]))

;; Grouping is transparent when comparing already-parsed expression trees.
;; Operator structure still matters: (a + b) * c differs from a + (b * c).
(define (expression-equivalent? first second)
  (define a (ungroup-expression first))
  (define b (ungroup-expression second))
  (match* (a b)
    [(`(fields ,left) `(fields ,right))
     ;; A field named group is a label, not a parenthesis group.
     (and (= (length left) (length right))
          (for/and ([entry (in-list left)] [other (in-list right)])
            (and (eq? (car entry) (car other))
                 (expression-equivalent? (cadr entry) (cadr other)))))]
    [(_ _)
     (if (and (pair? a) (pair? b))
         (and (expression-equivalent? (car a) (car b))
              (expression-equivalent? (cdr a) (cdr b)))
         (equal? a b))]))
