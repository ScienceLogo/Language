#lang racket/base

(provide (struct-out uncertain-value) plain-value value-field)

(struct uncertain-value (value uncertainty) #:transparent)

(define (plain-value value)
  (if (uncertain-value? value) (uncertain-value-value value) value))

(define (value-field value name missing)
  (cond [(and (eq? name 'u) (uncertain-value? value))
         (uncertain-value-uncertainty value)]
        [(hash? (plain-value value))
         (hash-ref (plain-value value) name missing)]
        [else missing]))
