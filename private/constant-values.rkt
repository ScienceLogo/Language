#lang racket/base
(require racket/list racket/match "uncertain-values.rkt" "value-kinds.rkt")
(provide constant-value no-constant unresolved? contains-unresolved? list-membership
         current-interface-test)

(define no-constant (gensym 'no-constant))

;; Record checking supplies this callback, keeping the expression evaluator
;; independent of the interface implementation.
(define current-interface-test
  (make-parameter (lambda (_name _value) no-constant)))

(define (unresolved? value)
  (or (eq? value no-constant) (eq? value 'unknown)))

(define (contains-unresolved? value)
  (cond
    [(uncertain-value? value) (contains-unresolved? (plain-value value))]
    [(unresolved? value) #t]
    [(list? value) (ormap contains-unresolved? value)]
    [(hash? value)
     (for/or ([part (in-hash-values value)])
       (contains-unresolved? part))]
    [else #f]))

;; The checker may lack a value even when the source did not supply unknown.
(define (contains-unavailable? value)
  (cond [(eq? value no-constant) #t]
        [(uncertain-value? value)
         (or (contains-unavailable? (uncertain-value-value value))
             (contains-unavailable? (uncertain-value-uncertainty value)))]
        [(list? value) (ormap contains-unavailable? value)]
        [(hash? value) (for/or ([part (in-hash-values value)]) (contains-unavailable? part))]
        [else #f]))

;; Membership has the same result as equality tests joined with or.
(define (list-membership value collection)
  (define needle (plain-value value))
  (define items (plain-value collection))
  (define unavailable-needle? (contains-unavailable? needle))
  (cond [(eq? items 'unknown) 'unknown]
        [(not (list? items)) no-constant]
        [else
         (for/fold ([answer #f]) ([item (in-list items)] #:break (eq? answer #t))
           (define candidate (plain-value item))
           (cond [(or unavailable-needle? (contains-unavailable? candidate)) no-constant]
                 [(equal? needle candidate) #t]
                 [else answer]))]))

(define (constant-value expression [lookup (lambda (_name) no-constant)] [partial? #f])
  (define (evaluate expression)
    (match expression
      [`(result ,name) (lookup name)]
      [`(literal ,value) value]
      [`(uncertain ,base ,description)
       (uncertain-value (evaluate base) (evaluate description))]
      [`(typed-default ,_ (,value)) (evaluate value)]
      [`(kind-test ,kind (,value))
       (define plain (plain-value (constant-value value lookup #t)))
       (cond [(eq? plain no-constant) no-constant]
             [(eq? plain 'unknown) 'unknown]
             [(memq kind value-kind-names) (eq? (value-kind plain) kind)]
             [else ((current-interface-test) kind plain)])]
      [`(list ,parts)
       (define values (map evaluate parts))
       (if (and (not partial?) (ormap contains-unresolved? values)) no-constant values)]
      [`(fields ,entries)
       (define values
         (for/list ([entry (in-list entries)])
           (cons (first entry) (evaluate (second entry)))))
       (if (and (not partial?) (ormap (lambda (entry) (contains-unresolved? (cdr entry))) values))
           no-constant
           (make-immutable-hasheq values))]
      [`(dot-update (,source ,changes))
       (define original (evaluate source))
       (define replacements (evaluate changes))
       (if (and (hash? original) (hash? replacements))
           (for/fold ([record original]) ([(name value) (in-hash replacements)])
             (hash-set record name value))
           no-constant)]
      [`(dot-select (,source ,selectors ...))
       (define container (plain-value (evaluate source)))
       (define (one selector)
         (match selector
           [`(literal ,n)
            (match source
              [`(list ,parts)
               (if (and (exact-positive-integer? n) (<= n (length parts)))
                   (evaluate (list-ref parts (sub1 n))) no-constant)]
              [_
               (if (and (list? container) (exact-positive-integer? n)
                        (<= n (length container)))
                   (list-ref container (sub1 n)) no-constant)])]
           [`(result ,field)
            (if (and (hash? container) (hash-has-key? container field))
                (hash-ref container field) no-constant)]
           [_
            (define n (evaluate selector))
            (if (and (list? container) (exact-positive-integer? n)
                     (<= n (length container)))
                (list-ref container (sub1 n)) no-constant)]))
       (define selected (map one selectors))
       (cond
         [(ormap (if partial? (lambda (value) (eq? value no-constant)) unresolved?) selected)
          no-constant]
         [(= (length selected) 1) (car selected)]
         [(hash? container)
          (for/hasheq ([selector (in-list selectors)]
                       [value (in-list selected)])
            (values (cadr selector) value))]
         [else selected])]
      [`(field-ref count ,receiver)
       ;; Item values need not be known to establish the number of positions.
       (value-field (constant-value receiver lookup #t) 'count no-constant)]
      [`(field-ref ,name ,receiver)
       (match receiver
         [`(fields ,entries)
          (define entry (assoc name entries))
          (if entry (evaluate (second entry)) no-constant)]
         [_
          (define record (evaluate receiver))
          (value-field record name no-constant)])]
      [`(range (,start ,end ,step))
       (define a (plain-value (evaluate start)))
       (define b (plain-value (evaluate end)))
       (define increment (plain-value (evaluate step)))
       (if (and (real? a) (exact? a) (real? b) (exact? b)
                (real? increment) (exact? increment) (not (zero? increment))
                (or (= a b) (and (< a b) (positive? increment))
                    (and (> a b) (negative? increment))))
           (for/list ([value (in-range a (+ b increment) increment)]
                      #:when (if (positive? increment) (<= value b) (>= value b))) value)
           no-constant)]
      [`(unary ,operator (,part))
       (define value (plain-value (evaluate part)))
       (cond
         [(eq? value 'unknown) 'unknown]
         [(unresolved? value) no-constant]
         [(eq? operator 'not)
          (if (boolean? value) (not value) no-constant)]
         [(eq? operator '-)
          (if (and (real? value) (exact? value)) (- value) no-constant)]
         [else no-constant])]
      [`(binary ,operator (,left ,right))
       (define a (plain-value (evaluate left)))
       (define b (plain-value (evaluate right)))
       (define (boolean-or-unknown? value)
         (or (boolean? value) (eq? value 'unknown)))
       (case operator
         [(and)
          (cond [(eq? a #f) #f]
                [(eq? b #f) #f]
                [(and (eq? a #t) (eq? b #t)) #t]
                [(and (boolean-or-unknown? a) (boolean-or-unknown? b)) 'unknown]
                [else no-constant])]
         [(or)
          (cond [(eq? a #t) #t]
                [(eq? b #t) #t]
                [(and (eq? a #f) (eq? b #f)) #f]
                [(and (boolean-or-unknown? a) (boolean-or-unknown? b)) 'unknown]
                [else no-constant])]
         [(xor)
          (cond [(and (boolean? a) (boolean? b)) (not (eq? a b))]
                [(and (boolean-or-unknown? a) (boolean-or-unknown? b)) 'unknown]
                [else no-constant])]
         [else
          (cond [(or (eq? a no-constant) (eq? b no-constant)) no-constant]
                [(or (eq? a 'unknown) (eq? b 'unknown)) 'unknown]
                [(or (not (and (real? a) (exact? a) (real? b) (exact? b)))
                     (and (eq? operator '/) (zero? b))) no-constant]
                [else
                 (case operator
                   [(+) (+ a b)]
                   [(-) (- a b)]
                   [(*) (* a b)]
                   [(/) (/ a b)]
                   [else no-constant])])])]
      [`(compare in (,left ,right))
       (define container (plain-value (constant-value right lookup #t)))
       (cond
         [(hash? container)
          (match left
            [`(result ,name) (hash-has-key? container name)]
            [_ no-constant])]
         [(list? container) (list-membership (constant-value left lookup #t) container)]
         [(eq? container 'unknown) 'unknown]
         [else no-constant])]
      [`(compare ,operator (,left ,right))
       (define a (plain-value (constant-value left lookup #t)))
       (define b (plain-value (constant-value right lookup #t)))
       (cond
         [(or (contains-unavailable? a) (contains-unavailable? b)) no-constant]
         [(eq? operator '==) (equal? a b)]
         [(eq? operator '!=) (not (equal? a b))]
         [(or (contains-unresolved? a) (contains-unresolved? b)) 'unknown]
         [(not (and (real? a) (real? b))) no-constant]
         [else
          (case operator
            [(<) (< a b)]
            [(<=) (<= a b)]
            [(>) (> a b)]
            [(>=) (>= a b)]
            [else no-constant])])]
      [_ no-constant]))

  (evaluate expression))
