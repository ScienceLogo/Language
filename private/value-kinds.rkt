#lang racket/base

(require "uncertain-values.rkt")

(provide value-kind-names value-kind)

(define value-kind-names '(number text boolean list record))

;; A kind describes the outer value, independently of its contents or u.
(define (value-kind value)
  (define plain (plain-value value))
  (cond [(and (real? plain) (exact? plain)) 'number]
        [(string? plain) 'text]
        [(boolean? plain) 'boolean]
        [(list? plain) 'list]
        [(hash? plain) 'record]
        [else #f]))
