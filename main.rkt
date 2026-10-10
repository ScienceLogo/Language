#lang racket/base

(require racket/match racket/string)

(provide (all-from-out racket/base) run-program)

;; The reader validates the complete method before producing this representation.
(define (run-program program)
  (match program
    [`(library ,_ ,_) (void)]
    [`(fragment ,_ ,_) (void)]
    [`(interface ,_ ,_) (void)]
    [`(workflow ,_ ,forms)
     (define procedures (make-hasheq))
     (for ([form (in-list forms)])
       (match form
         [`(to ,name ,inputs ,body)
          (hash-set! procedures name (cons inputs body))]
         [_ (void)]))
     (define no-result (gensym 'no-result))
     (define (decimal-text value)
       (define denominator-value (denominator value))
       (define (strip-factor n factor)
         (let loop ([remaining n] [count 0])
           (if (zero? (remainder remaining factor))
               (loop (quotient remaining factor) (add1 count))
               (values remaining count))))
       (define-values (after-twos twos) (strip-factor denominator-value 2))
       (define-values (remainder-value fives) (strip-factor after-twos 5))
       (if (not (= remainder-value 1))
           (number->string value)
           (let* ([places (max twos fives)]
                  [scaled (* (abs value) (expt 10 places))]
                  [digits (number->string scaled)]
                  [padded (string-append (make-string (max 0 (- (add1 places)
                                                          (string-length digits))) #\0)
                                         digits)]
                  [split (- (string-length padded) places)])
             (string-append (if (negative? value) "-" "")
                            (if (zero? places)
                                padded
                                (string-append (substring padded 0 split) "."
                                               (substring padded split)))))))
     (define (render-value value)
       (cond
         [(string? value) value]
         [(boolean? value) (if value "true" "false")]
         [(eq? value 'unknown) "unknown"]
         [(and (rational? value) (exact? value)) (decimal-text value)]
         [(list? value)
          (string-append "[" (string-join (map render-value value) " ") "]")]
         [else (format "~a" value)]))
     (define (numeric-range start end step)
       (unless (and (real? start) (exact? start)
                    (real? end) (exact? end)
                    (real? step) (exact? step))
         (error 'run-program "range bounds and step must be exact numbers"))
       (when (zero? step)
         (error 'run-program "range step must not be zero"))
       (when (or (and (< start end) (negative? step))
                 (and (> start end) (positive? step)))
         (error 'run-program "range step must move toward the end"))
       (let loop ([value start] [backward '()])
         (if (if (positive? step) (> value end) (< value end))
             (reverse backward)
             (loop (+ value step) (cons value backward)))))
     (define (value-of expression inputs scopes)
       (match expression
         [`(literal ,value) value]
         [`(list ,values)
          (for/list ([value (in-list values)])
            (value-of value inputs scopes))]
         [`(range (,start ,end ,step))
          (numeric-range (value-of start inputs scopes)
                         (value-of end inputs scopes)
                         (value-of step inputs scopes))]
         [`(parameter ,name) (hash-ref inputs name)]
         [`(result ,name)
          (let loop ([remaining scopes])
            (cond
              [(null? remaining) (error 'run-program "unknown result ~a" name)]
              [(hash-has-key? (car remaining) name)
               (hash-ref (car remaining) name)]
              [else (loop (cdr remaining))]))]))
     (define (condition-of expression inputs scopes)
       (define value
         (match expression
           [`(compare ,operator (,left ,right))
            (define a (value-of left inputs scopes))
            (define b (value-of right inputs scopes))
            (cond
              [(or (eq? a 'unknown) (eq? b 'unknown)) 'unknown]
              [(eq? operator '=) (equal? a b)]
              [(eq? operator '!=) (not (equal? a b))]
              [else
               (unless (and (real? a) (real? b))
                 (error 'run-program "ordered comparisons need numbers"))
               (case operator
                 [(<) (< a b)]
                 [(<=) (<= a b)]
                 [(>) (> a b)]
                 [(>=) (>= a b)])])]
           [_ (value-of expression inputs scopes)]))
       (unless (boolean? value)
         (error 'run-program
                (if (eq? value 'unknown)
                    "condition is undetermined; a human or external assessment must resolve it"
                    "condition must be true or false")))
       value)
     (define (call-procedure name arguments)
       (define definition (hash-ref procedures name))
       (define inputs (make-hasheq))
       (for ([input (in-list (car definition))]
             [argument (in-list arguments)])
         (hash-set! inputs input argument))
       (let/ec return
         (run-forms (cdr definition) inputs (list (make-hasheq)) return)
         no-result))
     (define (write-name name value scopes)
       (let loop ([remaining scopes])
         (cond
           [(null? remaining) (hash-set! (car scopes) name value)]
           [(hash-has-key? (car remaining) name)
            (hash-set! (car remaining) name value)]
           [else (loop (cdr remaining))])))
     (define (run-forms forms inputs scopes return)
       (for ([form (in-list forms)])
         (match form
           [`(import ,_ ,_ ,_ ,_ ,_) (void)]
           [`(implements ,_ ,_) (void)]
           [`(must-call ,_) (void)]
           [`(must-stage-order ,_) (void)]
           [`(stage ,_) (void)]
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
           [`(set ,name ,expression)
            (write-name name (value-of expression inputs scopes) scopes)]
           [`(repeat ,count-expression ,body)
            (define count (value-of count-expression inputs scopes))
            (unless (exact-nonnegative-integer? count)
              (error 'run-program "repeat count must be a nonnegative integer"))
            (for ([_ (in-range count)])
              (run-forms body inputs (cons (make-hasheq) scopes) return))]
           [`(for-each ,name ,collection-expression ,body)
            (define collection (value-of collection-expression inputs scopes))
            (unless (list? collection)
              (error 'run-program "for each needs an ordered sequence"))
            (for ([value (in-list collection)])
              (define local (make-hasheq))
              (hash-set! local name value)
              (run-forms body inputs (cons local scopes) return))]
           [`(if ,branches)
            (let choose ([remaining branches])
              (unless (null? remaining)
                (match (car remaining)
                  [`(branch ,condition ,body)
                   (if (or (not condition)
                           (condition-of condition inputs scopes))
                       (run-forms body inputs
                                  (cons (make-hasheq) scopes) return)
                       (choose (cdr remaining)))])))]
           [`(while ,condition ,body)
            (let loop ([count 0])
              (when (condition-of condition inputs scopes)
                (when (>= count 10000)
                  (error 'run-program "while loop did not terminate within 10000 iterations"))
                (run-forms body inputs (cons (make-hasheq) scopes) return)
                (loop (add1 count))))]
           [`(repeat-until ,condition ,body)
            (let loop ([count 0])
              (when (>= count 10000)
                (error 'run-program "repeat until did not terminate within 10000 iterations"))
              (define local-scopes (cons (make-hasheq) scopes))
              (run-forms body inputs local-scopes return)
              (unless (condition-of condition inputs local-scopes)
                (loop (add1 count))))]
           [`(print ,expression)
            (displayln (render-value (value-of expression inputs scopes)))]
           [`(output ,expression)
            (return (value-of expression inputs scopes))])))
     (run-forms forms (make-hasheq) (list (make-hasheq)) #f)]))
