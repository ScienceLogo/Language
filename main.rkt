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
         [`(to ,name ,inputs ,body)
          (hash-set! procedures name (cons inputs body))]
         [_ (void)]))
     (define no-result (gensym 'no-result))
     (define (value-of expression inputs scopes)
       (match expression
         [`(literal ,value) value]
         [`(parameter ,name) (hash-ref inputs name)]
         [`(result ,name)
          (let loop ([remaining scopes])
            (cond
              [(null? remaining) (error 'run-program "unknown result ~a" name)]
              [(hash-has-key? (car remaining) name)
               (hash-ref (car remaining) name)]
              [else (loop (cdr remaining))]))]))
     (define (call-procedure name arguments)
       (define definition (hash-ref procedures name))
       (define inputs (make-hasheq))
       (for ([input (in-list (car definition))]
             [argument (in-list arguments)])
         (hash-set! inputs input argument))
       (let/ec return
         (run-forms (cdr definition) inputs (list (make-hasheq)) return)
         no-result))
     (define (run-forms forms inputs scopes return)
       (for ([form (in-list forms)])
         (match form
           [`(to ,_ ,_ ,_) (void)]
           [`(call ,name ,arguments ,result-name)
            (define result
              (call-procedure name
                              (for/list ([argument (in-list arguments)])
                                (value-of argument inputs scopes))))
            (when result-name
              (when (eq? result no-result)
                (error 'run-program "procedure ~a returned no result" name))
              (hash-set! (car scopes) result-name result))]
           [`(sequence ,body)
            (run-forms body inputs (cons (make-hasheq) scopes) return)]
           [`(print ,expression)
            (displayln (value-of expression inputs scopes))]
           [`(output ,expression)
            (return (value-of expression inputs scopes))])))
     (run-forms forms (make-hasheq) (list (make-hasheq)) #f)]))
