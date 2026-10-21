#lang racket/base

(require racket/list racket/match racket/string
         "private/record-interfaces.rkt" "private/uncertain-values.rkt"
         "private/value-kinds.rkt"
         "private/expression-groups.rkt"
         (only-in "private/constant-values.rkt" list-membership no-constant current-interface-test))

(provide (all-from-out racket/base) run-program)

;; The reader validates the complete method before producing this representation.
(define (run-program program)
  (match program
    [`(library ,_ ,_) (void)]
    [`(fragment ,_ ,_) (void)]
    [`(interface ,_ ,_) (void)]
    [`(workflow ,_ ,forms)
     (define procedures (make-hasheq))
     (define declarations (make-hasheq))
     (for ([form (in-list forms)])
       (match form
         [`(to ,name ,inputs ,body)
          (hash-set! procedures name (cons inputs body))]
         [`(interface ,name ,parts)
          (hash-set! declarations (string->symbol name) parts)]
         [_ (void)]))
     (define interfaces (resolve-record-interfaces declarations))
     (define performer-expressions
       (for/hasheq ([form (in-list forms)]
                    #:when (match form [`(performer ,_ ,_) #t] [_ #f]))
         (values (cadr form) (caddr form))))
     (define resources
       (for/hasheq ([form (in-list forms)]
                    #:when (match form [`(resource ,_ ,_) #t] [_ #f]))
         (values (cadr form) #t)))
     (define proposition-expressions
       (make-hash
        (for/list ([form (in-list forms)]
                   #:when (match form [`(proposition ,_ ,_) #t] [_ #f]))
          (cons (cadr form) (caddr form)))))
     (define propositions (make-hash))
     (define proposition-roots (make-hasheq))
     (define initializing-propositions (make-hash))
     (define (plural type)
       (case type
         [(hypothesis) 'hypotheses]
         [(assumption) 'assumptions]
         [(conclusion) 'conclusions]
         [else (error 'run-program "unknown proposition type ~a" type)]))
     (define (singular collection)
       (case collection
         [(hypotheses) 'hypothesis]
         [(assumptions) 'assumption]
         [(conclusions) 'conclusion]
         [else (error 'run-program "unknown proposition collection ~a" collection)]))
     (define (proposition? value)
       (and (hash? value)
            (memq (hash-ref value 'type #f)
                  '(hypothesis assumption conclusion))
            (symbol? (hash-ref value 'name #f))))
     (define (proposition-value type name fields)
       (unless (hash? fields)
         (error 'run-program "~a ~a needs named fields" type name))
       (for ([field (in-hash-keys fields)])
         (unless (memq field '(type name text hypotheses assumptions conclusions))
           (error 'run-program "unknown proposition field ~a" field)))
       (when (or (and (hash-has-key? fields 'type)
                      (not (eq? (hash-ref fields 'type) type)))
                 (and (hash-has-key? fields 'name)
                      (not (eq? (hash-ref fields 'name) name))))
         (error 'run-program "proposition type and name cannot change"))
       (unless (string? (hash-ref fields 'text #f))
         (error 'run-program "~a ~a needs quoted text" type name))
       (for/fold ([result (hash-set (hash-set fields 'type type) 'name name)])
                 ([collection '(hypotheses assumptions conclusions)])
         (define raw-children (hash-ref result collection (hasheq)))
         (define children (if (null? raw-children) (hasheq) raw-children))
         (unless (hash? children)
           (error 'run-program "~a needs named entries" collection))
         (hash-set result collection
                   (for/hasheq ([(child-name child) (in-hash children)])
                     (unless (symbol? child-name)
                       (error 'run-program "proposition child needs a name"))
                     (values child-name
                             (proposition-value (singular collection)
                                                child-name child))))))
     (define (proposition-of type name)
       (define key (list type name))
       (hash-ref propositions key
                 (lambda ()
                   (when (hash-ref initializing-propositions key #f)
                     (error 'run-program "proposition reference cycle through ~a" name))
                   (hash-set! initializing-propositions key #t)
                   (define value
                     (proposition-value
                      type name
                      (value-of (hash-ref proposition-expressions key)
                                (make-hasheq) (list (make-hasheq)))))
                   (hash-remove! initializing-propositions key)
                   (hash-set! propositions key value)
                   value)))
     (define (proposition-root collection)
       (hash-ref proposition-roots collection
                 (lambda ()
                   (for/hasheq ([key (in-hash-keys proposition-expressions)]
                                #:when (eq? (first key) (singular collection)))
                     (values (second key)
                             (proposition-of (first key) (second key)))))))
     (define (normalize-root collection value)
       (unless (hash? value)
         (error 'run-program "~a needs named propositions" collection))
       (for/hasheq ([(name child) (in-hash value)])
         (values name (proposition-value (singular collection) name child))))
     (define (resource-root expression)
       (match (ungroup-expression expression)
         [`(result ,name) (and (hash-has-key? resources name) name)]
         [`(field-ref ,_ ,receiver) (resource-root receiver)]
         [`(dot-select (,receiver ,_ ...)) (resource-root receiver)]
         [_ #f]))
     (define no-result (gensym 'no-result))
     (define (normalize-uncertainty value)
       (unless (hash? value)
         (error 'run-program "u needs named fields"))
       (for ([name (in-hash-keys value)])
         (unless (memq name '(declared omitted))
           (error 'run-program "u fields must be declared or omitted")))
       (for/fold ([result (hasheq)]) ([name '(declared omitted)])
         (define collection (hash-ref value name (hasheq)))
         (define sources (if (null? collection) (hasheq) collection))
         (unless (hash? sources)
           (error 'run-program "u ~a needs named entries" name))
         (hash-set
          result name
          (for/hasheq ([(source fields) (in-hash sources)])
            (define details (if (null? fields) (hasheq) fields))
            (unless (hash? details)
              (error 'run-program "u source ~a needs named fields" source))
            (values source details)))))
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
         [(uncertain-value? value) (render-value (uncertain-value-value value))]
         [(string? value) value]
         [(boolean? value) (if value "true" "false")]
         [(eq? value 'unknown) "unknown"]
         [(and (rational? value) (exact? value)) (decimal-text value)]
         [(hash? value)
          (string-append
           "["
           (string-join
            (for/list ([name (in-list
                              (sort (hash-keys value) string<?
                                    #:key symbol->string))])
              (define field-value (hash-ref value name))
              (format "~a = ~a" name
                      (if (string? field-value)
                          (format "~s" field-value)
                          (render-value field-value))))
            " ")
           "]")]
         [(list? value)
          (string-append "[" (string-join (map render-value value) " ") "]")]
         [else (format "~a" value)]))
     (define (numeric-range start end step)
       (set! start (plain-value start))
       (set! end (plain-value end))
       (set! step (plain-value step))
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
     (define (boolean-value value)
       (set! value (plain-value value))
       (unless (or (boolean? value) (eq? value 'unknown))
         (error 'run-program "Boolean operator needs true or false"))
       value)
     (define (number-value value)
       (set! value (plain-value value))
       (unless (and (real? value) (exact? value))
         (error 'run-program "arithmetic needs exact numbers"))
       value)
     (define (contains-unknown? value)
       (cond
         [(uncertain-value? value)
          (contains-unknown? (uncertain-value-value value))]
         [(eq? value 'unknown) #t]
         [(list? value) (ormap contains-unknown? value)]
         [(hash? value)
          (for/or ([part (in-hash-values value)])
            (contains-unknown? part))]
         [else #f]))
     (define (selector-key selector container inputs scopes)
       (set! container (plain-value container))
       (cond
         [(or (hash? container) (record-interface? container))
          (match (ungroup-expression selector)
            [`(result ,name) name]
            [_ (error 'run-program "record selection needs a field name")])]
         [(list? container)
          (define n
            (match (ungroup-expression selector)
              [`(result ,name)
               (or (string->number (symbol->string name))
                   (value-of selector inputs scopes))]
              [_ (value-of selector inputs scopes)]))
          (when (eq? n 'unknown)
            (error 'run-program "list position is unknown"))
          (unless (and (exact-positive-integer? n) (<= n (length container)))
            (error 'run-program "list position must be between 1 and ~a"
                   (length container)))
          n]
         [else (error 'run-program "dot selection needs a record or list")]))
     (define (select-one container selector inputs scopes)
       (set! container (plain-value container))
       (if (and (list? container)
                (eq? (value-of selector inputs scopes) 'unknown))
           'unknown
           (let ([key (selector-key selector container inputs scopes)])
             (cond
               [(record-interface? container)
                (define name (string->symbol (record-interface-name container)))
                (or (resolve-interface-reference
                     (hasheq name container)
                     (string->symbol (format "~a.~a" name key)))
                    (error 'run-program "missing nested interface part ~a" key))]
               [(hash? container)
                (hash-ref container key
                          (lambda () (error 'run-program "missing field ~a" key)))]
               [else (list-ref container (sub1 key))]))))
     (define (replace-one container key value)
       (cond
         [(hash? container) (hash-set container key value)]
         [(list? container) (list-set container (sub1 key) value)]
         [else (error 'run-program "dot update needs a record or list")]))
     (define (merge-records old changes)
       (for/fold ([result old]) ([(key value) (in-hash changes)])
         (define earlier (hash-ref result key #f))
         (when (and (hash-has-key? result key)
                    (hash? value) (not (hash? earlier)))
           (error 'run-program "nested update needs a record at ~a" key))
         (hash-set result key
                   (if (and (hash? earlier) (hash? value))
                       (merge-records earlier value)
                       value))))
     (define (collection-target expression inputs scopes)
       (match (ungroup-expression expression)
         [`(result ,name)
          (and (memq name '(hypotheses assumptions conclusions)) name)]
         [`(field-ref ,name ,receiver)
          (and (memq name '(hypotheses assumptions conclusions))
               (proposition? (value-of receiver inputs scopes))
               name)]
         [_ #f]))
     (define (add-child collection child)
       (define name (hash-ref child 'name))
       (when (hash-has-key? collection name)
         (error 'run-program "duplicate ~a ~a; use = to update it"
                (hash-ref child 'type) name))
       (hash-set collection name child))
     (define (patch-value original entries inputs scopes)
       (when (uncertain-value? original)
         (error 'run-program "update a qualified value with = and an explicit u description"))
       (if (record-interface? original)
           (interface-record
            original
            (for/hasheq ([entry (in-list entries)])
              (values (car entry) (value-of (cadr entry) inputs scopes)))
            (lambda (default) (value-of default inputs scopes)))
           (for/fold ([current original]) ([entry (in-list entries)])
         (match-define `(,raw-key ,expression) entry)
         (define key
           (if (hash? current)
               raw-key
               (selector-key `(result ,raw-key) current inputs scopes)))
         (define value (value-of expression inputs scopes))
         (if (hash? current)
             (merge-records current (hasheq key value))
             (replace-one current key value)))))
     (define (value-of expression inputs scopes)
       (call-with-interface-context
        interfaces (lambda () (evaluate-value expression inputs scopes))
        (lambda (default) (value-of default inputs scopes))))
     (define (evaluate-value expression inputs scopes)
       (match (ungroup-expression expression)
         [`(literal ,value) value]
         [`(typed-default ,_ (,value)) (value-of value inputs scopes)]
         [`(kind-test ,kind (,expression))
          (define value (plain-value (value-of expression inputs scopes)))
          (cond [(eq? value 'unknown) 'unknown]
                [(memq kind value-kind-names) (eq? (value-kind value) kind)]
                [else
                 (define answer ((current-interface-test) kind value))
                 (if (eq? answer no-constant) 'unknown answer)])]
         [`(uncertain ,base ,description)
          (uncertain-value (plain-value (value-of base inputs scopes))
                           (normalize-uncertainty
                            (value-of description inputs scopes)))]
         [`(list ,values)
          (for/list ([value (in-list values)])
            (value-of value inputs scopes))]
         [`(fields ,entries)
          (make-immutable-hasheq
           (for/list ([entry (in-list entries)])
             (match entry
               [`(,name ,value)
                (cons name (value-of value inputs scopes))])))]
         [`(proposition-value (,type ,name) ,fields)
          (proposition-value type name (value-of fields inputs scopes))]
         [`(dot-select (,receiver ,selectors ...))
          (if (resource-root expression)
              'unknown
              (let ([container (plain-value (value-of receiver inputs scopes))])
                (if (= (length selectors) 1)
                    (select-one container (car selectors) inputs scopes)
                    (if (hash? container)
                        (for/hasheq ([selector (in-list selectors)])
                          (define key (selector-key selector container inputs scopes))
                          (values key (select-one container selector inputs scopes)))
                        (for/list ([selector (in-list selectors)])
                          (select-one container selector inputs scopes))))))]
         [`(dot-update (,receiver (fields ,entries)))
          (patch-value (value-of receiver inputs scopes) entries inputs scopes)]
         [`(augment ,_ (,left ,right))
          (define old (value-of left inputs scopes))
          (define added (value-of right inputs scopes))
          (when (or (uncertain-value? old) (uncertain-value? added))
            (error 'run-program
                   "update a qualified value with = and an explicit u description"))
          (cond
            [(list? old) (append old (list added))]
            [(and (proposition? old) (proposition? added))
             (when (and (eq? (hash-ref old 'type) (hash-ref added 'type))
                        (eq? (hash-ref old 'name) (hash-ref added 'name)))
               (error 'run-program "a proposition cannot contain itself"))
             (define collection (plural (hash-ref added 'type)))
             (hash-set old collection
                       (add-child (hash-ref old collection) added))]
            [(and (hash? old) (collection-target left inputs scopes)
                  (proposition? added))
             (unless (eq? (hash-ref added 'type)
                          (singular (collection-target left inputs scopes)))
               (error 'run-program "wrong proposition type for ~a"
                      (collection-target left inputs scopes)))
             (add-child old added)]
            [(or (proposition? old) (collection-target left inputs scopes))
             (error 'run-program "use += with a named proposition to add a child")]
            [(hash? old)
             (unless (hash? added)
               (error 'run-program "record update needs named fields"))
             (merge-records old added)]
            [(or (eq? old 'unknown) (eq? added 'unknown)) 'unknown]
            [else (+ (number-value old) (number-value added))])]
         [`(field-ref ,name ,receiver)
          (cond
            [(resource-root expression) 'unknown]
            [(eq? name 'count)
             (define container (plain-value (value-of receiver inputs scopes)))
             (cond [(list? container) (length container)]
                   [(eq? container 'unknown) 'unknown]
                   [(or (hash? container) (record-interface? container))
                    (select-one container '(result count) inputs scopes)]
                   [else (error 'run-program ".count needs a list or a record field")])]
            [(eq? name 'u)
             (define value (value-of receiver inputs scopes))
             (unless (uncertain-value? value)
               (error 'run-program "this value has no u description"))
             (uncertain-value-uncertainty value)]
            [else
             (match (ungroup-expression receiver)
               [`(result ,collection)
                (if (and (memq collection '(hypotheses assumptions conclusions))
                         (hash-has-key? proposition-expressions
                                        (list (singular collection) name))
                         (not (hash-has-key? proposition-roots collection)))
                    (proposition-of (singular collection) name)
                    (let ([record (plain-value (value-of receiver inputs scopes))])
                      (unless (or (hash? record) (record-interface? record))
                        (error 'run-program "field ~a needs a named-field value" name))
                      (select-one record `(result ,name) inputs scopes)))]
               [_
                (define record (plain-value (value-of receiver inputs scopes)))
                (unless (or (hash? record) (record-interface? record))
                  (error 'run-program "field ~a needs a named-field value" name))
                (select-one record `(result ,name) inputs scopes)])])]
         [`(range (,start ,end ,step))
          (numeric-range (value-of start inputs scopes)
                         (value-of end inputs scopes)
                         (value-of step inputs scopes))]
         [`(unary ,operator (,part))
          (define value (plain-value (value-of part inputs scopes)))
          (case operator
            [(not)
             (define checked (boolean-value value))
             (if (eq? checked 'unknown) 'unknown (not checked))]
            [(-)
             (if (eq? value 'unknown) 'unknown (- (number-value value)))])]
         [`(binary ,operator (,left ,right))
          (define a (plain-value (value-of left inputs scopes)))
          (case operator
            [(and or)
             (define first (boolean-value a))
             (cond
               [(and (eq? operator 'and) (eq? first #f)) #f]
               [(and (eq? operator 'or) (eq? first #t)) #t]
               [else
                (define second (boolean-value (value-of right inputs scopes)))
                (cond [(eq? operator 'and)
                       (if (eq? second #f) #f
                           (if (eq? first 'unknown) 'unknown second))]
                      [else
                       (if (eq? second #t) #t
                           (if (eq? first 'unknown) 'unknown second))])])]
            [(xor)
             (define first (boolean-value a))
             (define second (boolean-value (value-of right inputs scopes)))
             (if (or (eq? first 'unknown) (eq? second 'unknown))
                 'unknown
                 (not (eq? first second)))]
            [else
             (define b (plain-value (value-of right inputs scopes)))
             (if (or (eq? a 'unknown) (eq? b 'unknown))
                 'unknown
                 (let ([x (number-value a)] [y (number-value b)])
                   (case operator
                     [(+) (+ x y)]
                     [(-) (- x y)]
                     [(*) (* x y)]
                     [(/)
                      (when (zero? y)
                        (error 'run-program "division by zero"))
                      (/ x y)])))])]
         [`(compare in (,left ,right))
          (define container (plain-value (value-of right inputs scopes)))
          (cond
            [(hash? container)
             (match (ungroup-expression left)
               [`(result ,name) (hash-has-key? container name)]
               [_ (error 'run-program "in needs an unquoted field name on the left of a record")])]
            [(list? container)
             (define answer (list-membership (value-of left inputs scopes) container))
             (if (eq? answer no-constant) 'unknown answer)]
            [(eq? container 'unknown) 'unknown]
            [else (error 'run-program "in needs a list or record on its right")])]
         [`(compare ,operator (,left ,right))
          (define a (plain-value (value-of left inputs scopes)))
          (define b (plain-value (value-of right inputs scopes)))
          (cond
            [(eq? operator '==) (equal? a b)]
            [(eq? operator '!=) (not (equal? a b))]
            [(or (contains-unknown? a) (contains-unknown? b)) 'unknown]
            [else
             (unless (and (real? a) (real? b))
               (error 'run-program "ordered comparisons need numbers"))
             (case operator
               [(<) (< a b)]
               [(<=) (<= a b)]
               [(>) (> a b)]
               [(>=) (>= a b)])])]
         [`(parameter ,name) (hash-ref inputs name)]
         [`(result ,name)
          (cond
            [(memq name '(hypotheses assumptions conclusions))
             (proposition-root name)]
            [(hash-has-key? interfaces name)
             (hash-ref interfaces name)]
            [(hash-has-key? performer-expressions name)
             (value-of (hash-ref performer-expressions name)
                       (make-hasheq) (list (make-hasheq)))]
            [else (let loop ([remaining scopes])
            (cond
              [(null? remaining) (error 'run-program "unknown result ~a" name)]
              [(hash-has-key? (car remaining) name)
               (hash-ref (car remaining) name)]
              [else (loop (cdr remaining))]))])]))
     (define (condition-of expression inputs scopes)
       (define value (plain-value (value-of expression inputs scopes)))
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
     (define (check-no-new-propositions previous revised)
       (for ([(name child) (in-hash revised)])
         (unless (hash-has-key? previous name)
           (error 'run-program "missing proposition ~a; use += to add it" name))
         (when (proposition? child)
           (define old-child (hash-ref previous name))
           (for ([collection '(hypotheses assumptions conclusions)])
             (check-no-new-propositions
              (hash-ref old-child collection)
              (hash-ref child collection))))))
     (define (write-name name value scopes [allow-new? #f])
       (if (memq name '(hypotheses assumptions conclusions))
           (let ([revised (normalize-root name value)])
             (unless allow-new?
               (check-no-new-propositions (proposition-root name) revised))
             (hash-set! proposition-roots name revised))
           (let loop ([remaining scopes])
             (cond
               [(null? remaining) (hash-set! (car scopes) name value)]
               [(hash-has-key? (car remaining) name)
                (hash-set! (car remaining) name value)]
               [else (loop (cdr remaining))]))))
     (define (assign-path target value inputs scopes [allow-new? #f])
       (match target
         [`(result ,name) (write-name name value scopes allow-new?)]
         [`(field-ref ,field ,receiver)
          (if (eq? field 'u)
              (let ([old (value-of receiver inputs scopes)])
                (unless (uncertain-value? old)
                  (error 'run-program "this value has no u description"))
                (assign-path receiver
                             (uncertain-value (uncertain-value-value old)
                                              (normalize-uncertainty value))
                             inputs scopes allow-new?))
              (let ([container
                     (with-handlers ([(lambda (e)
                                        (and (exn:fail? e)
                                             (regexp-match? #rx"missing field"
                                                            (exn-message e))))
                                     (lambda (_) (hasheq))])
                       (value-of receiver inputs scopes))])
                (when (and (eq? field 'count) (list? (plain-value container)))
                  (error 'run-program "the list property .count is read only"))
                (unless (hash? container)
                  (error 'run-program "field update needs a record"))
                (when (and (collection-target receiver inputs scopes)
                           (not (hash-has-key? container field)))
                  (error 'run-program "missing proposition ~a; use += to add it" field))
                (assign-path receiver (hash-set container field value)
                             inputs scopes allow-new?)))]
         [`(dot-select (,receiver ,selector))
          (define container (value-of receiver inputs scopes))
          (define key (selector-key selector container inputs scopes))
          (assign-path receiver (replace-one container key value)
                       inputs scopes allow-new?)]
         [_ (error 'run-program "update needs one named field or list position")]))
     (define (run-forms forms inputs scopes return)
       (for ([form (in-list forms)])
         (match form
           [`(import ,_ ,_ ,_ ,_ ,_) (void)]
           [`(included-file ,_ ,_) (void)]
           [`(implements ,_ ,_) (void)]
           [`(must-call ,_) (void)]
           [`(must-stage-order ,_) (void)]
           [`(implement ,_ ,_) (void)]
           [`(interface ,_ ,_) (void)]
           [`(performer ,_ ,_) (void)]
           [`(resource ,_ ,_) (void)]
           [`(proposition ,_ ,_) (void)]
           [`(about ,_) (void)]
           [(list 'stage _ _ ...) (void)]
           [`(state-stage ,_ ,_ ,_ ,_ ,_) (void)]
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
           [`(assignment ,name ,expression)
            (define value (value-of expression inputs scopes))
            (when (record-interface? value)
              (error 'run-program "an interface needs .[field = value] to construct a record"))
            (write-name name value scopes
                        (match expression [`(augment ,_ ,_) #t] [_ #f]))]
           [`(path-assignment ,target ,expression)
            (define value (value-of expression inputs scopes))
            (unless (resource-root target)
              (assign-path target value inputs scopes
                           (match expression [`(augment ,_ ,_) #t] [_ #f])))]
           [`(path-update-command (dot-update (,receiver (fields ,entries))))
            (assign-path receiver
                         (patch-value (value-of receiver inputs scopes)
                                      entries inputs scopes)
                         inputs scopes)]
           [`(repeat ,count-expression ,body)
            (define count (plain-value (value-of count-expression inputs scopes)))
            (unless (exact-nonnegative-integer? count)
              (error 'run-program "repeat count must be a nonnegative integer"))
            (for ([_ (in-range count)])
              (run-forms body inputs (cons (make-hasheq) scopes) return))]
           [`(for-each ,name ,collection-expression ,body)
            (define collection (plain-value
                                (value-of collection-expression inputs scopes)))
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
     (for ([key (in-hash-keys proposition-expressions)])
       (proposition-of (first key) (second key)))
     (run-forms forms (make-hasheq) (list (make-hasheq)) #f)]))
