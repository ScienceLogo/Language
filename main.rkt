#lang racket/base

(require racket/match)

(provide (all-from-out racket/base) run-program)

;; The reader validates the complete method before producing this representation.
(define (run-program program)
  (match program
    [`(investigate ,_ ,forms)
     (define procedures (make-hasheq))
     (for ([form (in-list forms)])
       (match form
         [`(to ,name ,body) (hash-set! procedures name body)]
         [_ (void)]))
     (define (run-forms forms)
       (for ([form (in-list forms)])
         (match form
           [`(to ,_ ,_) (void)]
           [`(call ,name) (run-forms (hash-ref procedures name))]
           [`(sequence ,body) (run-forms body)]
           [`(print ,message) (displayln message)])))
     (run-forms forms)]))
