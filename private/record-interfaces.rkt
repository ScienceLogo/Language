#lang racket/base

(require racket/list racket/match racket/string "constant-values.rkt")

(provide (struct-out record-interface)
         (struct-out record-field)
         (struct-out record-requirement)
         (struct-out requirement-result)
         resolve-record-interfaces
         interface-reference-root
         resolve-interface-reference
         resolve-interface-target
         interface-record
         complete-interface-record
         missing-interface-fields
         undetermined-interface-fields
         interface-requirement-results
         requirement-references
         interface-guard-value
         combine-interface-guards
         interface-branch-guards)

;; The caller evaluates defaults in its own value environment.
(struct record-interface (name fields requirements) #:transparent)
(struct record-field (name default required? children guard requirements) #:transparent)
(struct record-requirement (expression guard) #:transparent)
(struct requirement-result (scope expression outcome missing) #:transparent)

;; A requirement's names refer to entries of its surrounding interface part.
(define (requirement-references expression)
  (define references '())
  (define (path expression)
    (match expression
      [`(result ,name) (list name)]
      [`(field-ref ,name ,receiver)
       (define parent (path receiver))
       (and parent (append parent (list name)))]
      [_ #f]))
  (define (walk expression)
    (define location (path expression))
    (cond [location (set! references (cons location references))]
          [(pair? expression)
           (match expression
             [`(literal ,_) (void)]
             [`(fields ,entries) (for ([entry (in-list entries)]) (walk (cadr entry)))]
             [`(dot-select (,receiver ,selectors ...))
              (walk receiver)
              (for ([selector (in-list selectors)] #:unless (eq? (car selector) 'result))
                (walk selector))]
             [_ (for ([part (in-list expression)]) (walk part))])]))
  (walk expression)
  (remove-duplicates (reverse references)))

;; Declarations map interface names to reader datums: (extends Parent) and
;; (interface-field name default-or-#f required? children-or-#f), conditional
;; branches, and (interface-requirement expression).
;; A named group has child declarations; a value field has #f children.
(define (interface-reference-root declarations reference)
  (define text (symbol->string reference))
  (for/first ([name (in-list (sort (hash-keys declarations) >
                                 #:key (lambda (name) (string-length (symbol->string name)))))]
              #:when (or (eq? name reference)
                         (string-prefix? text (string-append (symbol->string name) "."))))
    name))

(define (resolve-interface-reference interfaces reference)
  (define root (interface-reference-root interfaces reference))
  (and root
       (let walk ([interface (hash-ref interfaces root)]
                  [remaining (substring (symbol->string reference)
                                        (string-length (symbol->string root)))])
         (cond
           [(string=? remaining "") interface]
           [else
            (define text (substring remaining 1))
            (define group
              (for/first ([field (in-list (sort (record-interface-fields interface) >
                                              #:key (lambda (field)
                                                      (string-length (symbol->string
                                                                      (record-field-name field))))))]
                          #:when (and (record-field-children field)
                                      (or (string=? text (symbol->string (record-field-name field)))
                                          (string-prefix? text
                                                          (string-append
                                                           (symbol->string (record-field-name field)) ".")))))
                field))
            (and group
                 (walk (record-interface
                        (string-append (record-interface-name interface) "."
                                       (symbol->string (record-field-name group)))
                        (record-field-children group)
                        (record-field-requirements group))
                       (substring text (string-length (symbol->string
                                                        (record-field-name group))))))]))))

(define (resolve-interface-target interfaces reference)
  (or (resolve-interface-reference interfaces reference)
      (let ([root (interface-reference-root interfaces reference)])
        (and root
             (let walk ([fields (record-interface-fields (hash-ref interfaces root))]
                        [path (substring (symbol->string reference)
                                         (add1 (string-length (symbol->string root))))])
               (for/or ([field (in-list fields)])
                 (define name (symbol->string (record-field-name field)))
                 (cond [(string=? name path) field]
                       [(and (record-field-children field)
                             (string-prefix? path (string-append name ".")))
                        (walk (record-field-children field) (substring path (add1 (string-length name))))]
                       [else #f])))))
      (let ([root (interface-reference-root interfaces reference)])
        (and root
             (let ([requested (map string->symbol
                                   (string-split (substring (symbol->string reference)
                                                            (add1 (string-length (symbol->string root)))) "."))])
               (define (mentioned? fields requirements [prefix '()])
                 (or (for*/or ([requirement (in-list requirements)]
                               [path (in-list (requirement-references (record-requirement-expression requirement)))])
                       (define full (append prefix path))
                       (and (<= (length requested) (length full))
                            (equal? requested (take full (length requested)))))
                     (for/or ([field (in-list fields)] #:when (record-field-children field))
                       (mentioned? (record-field-children field) (record-field-requirements field)
                                   (append prefix (field-path field))))))
               (define interface (hash-ref interfaces root))
               (and (mentioned? (record-interface-fields interface) (record-interface-requirements interface))
                    (record-field (string->symbol (string-join (map symbol->string requested) "."))
                                  #f #t #f #f '())))))))

(define (combine-interface-guards outer inner)
  (cond [(not outer) inner]
        [(not inner) outer]
        [else `(binary and (,outer ,inner))]))

(define (interface-branch-guards conditions)
  (define previous #f)
  (for/list ([condition (in-list conditions)])
    (define guard
      (combine-interface-guards (and previous `(unary not (,previous))) condition))
    (when condition
      (set! previous (if previous `(binary or (,previous ,condition)) condition)))
    guard))

(define (declaration-fields parts [guard #f])
  (append*
   (for/list ([part (in-list parts)])
     (case (car part)
       [(interface-field)
        (list (record-field (cadr part) (caddr part) (cadddr part)
                            (and (list-ref part 4) (declaration-fields (list-ref part 4)))
                            guard
                            (if (list-ref part 4) (declaration-requirements (list-ref part 4)) '())))]
       [(interface-if)
        (define branches (cadr part))
        (append*
         (for/list ([branch (in-list branches)]
                    [condition (in-list (interface-branch-guards (map cadr branches)))])
           (declaration-fields (caddr branch) (combine-interface-guards guard condition))))]
       [else '()]))))

(define (declaration-requirements parts [guard #f])
  (append*
   (for/list ([part (in-list parts)])
     (case (car part)
       [(interface-requirement) (list (record-requirement (cadr part) guard))]
       [(interface-if)
        (define branches (cadr part))
        (append*
         (for/list ([branch (in-list branches)]
                    [condition (in-list (interface-branch-guards (map cadr branches)))])
           (declaration-requirements (caddr branch) (combine-interface-guards guard condition))))]
       [else '()]))))

;; Resolution permits forward references.
(define (resolve-record-interfaces declarations
                                   [fail (lambda (_name message)
                                           (error 'resolve-record-interfaces "~a" message))])
  (define resolved (make-hasheq))
  (define active (make-hasheq))
  (define (visit name [requestor name])
    (unless (hash-has-key? declarations name)
      (fail requestor (format "unknown parent interface ~a" name)))
    (when (hash-ref active name #f)
      (fail requestor (format "interface extension cycle through ~a" name)))
    (hash-ref resolved name
              (lambda ()
                (hash-set! active name #t)
                (define parts (hash-ref declarations name))
                (define own (declaration-fields parts))
                (define own-names (map record-field-name own))
                (define inherited '())
                (define requirements (declaration-requirements parts))
                (for ([part (in-list parts)] #:when (eq? (car part) 'extends))
                  (define parent (visit (cadr part) name))
                  (set! requirements (append (record-interface-requirements parent) requirements))
                  (for ([field (in-list (record-interface-fields parent))]
                        #:unless (memq (record-field-name field) own-names))
                    (define existing
                      (findf (lambda (earlier)
                               (eq? (record-field-name earlier) (record-field-name field)))
                             inherited))
                    (cond
                      [(not existing)
                       (set! inherited (append inherited (list field)))]
                      [(not (equal? existing field))
                       (fail name
                             (format "conflicting inherited field ~a in ~a; declare it explicitly"
                                     (record-field-name field) name))])))
                (define result
                  (record-interface (symbol->string name) (append inherited own)
                                    (remove-duplicates requirements)))
                (hash-remove! active name)
                (hash-set! resolved name result)
                result)))
  (for ([name (in-list (sort (hash-keys declarations) string<?
                             #:key symbol->string))])
    (visit name))
  resolved)

(define absent (gensym 'absent))
(define (field-path field)
  (map string->symbol (string-split (symbol->string (record-field-name field)) ".")))
(define (path-value record path)
  (cond [(null? path) record]
        [(and (hash? record) (hash-has-key? record (car path)))
         (path-value (hash-ref record (car path)) (cdr path))]
        [else absent]))

(define (interface-guard-value expression record)
  (define (known value)
    (cond [(memq value '(undetermined not-a-record)) 'unknown]
          [(hash? value) (for/hasheq ([(name part) (in-hash value)]) (values name (known part)))]
          [(list? value) (map known value)]
          [else value]))
  (define value
    (if expression
        (constant-value expression (lambda (name) (known (hash-ref record name 'unknown))))
        #t))
  (if (boolean? value) value 'unknown))

(define (interface-field-gaps interface record [evaluate-guard interface-guard-value])
  (unless (record-interface? interface)
    (raise-argument-error 'missing-interface-fields "record-interface?" interface))
  (define missing '())
  (define pending '())
  (define (walk fields value [prefix ""] [outer #t])
    (for ([field (in-list fields)])
       (define name (string-append prefix (symbol->string (record-field-name field))))
       (define found (path-value value (field-path field)))
       (define own (if (record-field-guard field)
                       (evaluate-guard (record-field-guard field) value) #t))
       (define status (cond [(or (eq? own #f) (eq? outer #f)) #f]
                            [(and (eq? own #t) (eq? outer #t)) #t]
                            [else 'unknown]))
       (define (gap)
         (if (eq? status #t)
             (set! missing (cons (string->symbol name) missing))
             (set! pending (cons (string->symbol name) pending))))
       (unless (eq? status #f)
         (cond [(eq? found absent) (when (record-field-required? field) (gap))]
               [(record-field-children field)
                (if (hash? found)
                    (walk (record-field-children field) found (string-append name ".") status)
                    (gap))]))))
  (walk (record-interface-fields interface) record)
  (values (reverse missing) (reverse pending)))

(define (missing-interface-fields interface record [evaluate-guard interface-guard-value])
  (define-values (missing _pending) (interface-field-gaps interface record evaluate-guard))
  missing)

(define (undetermined-interface-fields interface record [evaluate-guard interface-guard-value])
  (define-values (_missing pending) (interface-field-gaps interface record evaluate-guard))
  pending)

(define (interface-requirement-results interface record [evaluate interface-guard-value])
  (define results '())
  (define (and-status first second)
    (cond [(or (eq? first #f) (eq? second #f)) #f]
          [(and (eq? first #t) (eq? second #t)) #t]
          [else 'unknown]))
  (define (walk fields requirements value [prefix '()] [outer #t])
    (for ([requirement (in-list requirements)])
      (define guard (record-requirement-guard requirement))
      (define active (and-status outer (if guard (evaluate guard value) #t)))
      (unless (eq? active #f)
        (define expression (record-requirement-expression requirement))
        (define missing
          (for/list ([path (in-list (requirement-references expression))]
                     #:when (eq? (path-value value (if (memq 'u path) (take path 1) path)) absent))
            (string->symbol (string-join (map symbol->string (append prefix path)) "."))))
        (define outcome
          (cond [(pair? missing) (if (eq? active #t) 'violated 'undetermined)]
                [else
                 (define answer (evaluate expression value))
                 (cond [(eq? answer #t) 'satisfied]
                       [(and (eq? answer #f) (eq? active #t)) 'violated]
                       [else 'undetermined])]))
        (set! results (cons (requirement-result prefix expression outcome missing) results))))
    (for ([field (in-list fields)] #:when (record-field-children field))
      (define found (path-value value (field-path field)))
      (define guard (record-field-guard field))
      (define active (and-status outer (if guard (evaluate guard value) #t)))
      (when (and (hash? found) (not (eq? active #f)))
        (walk (record-field-children field) (record-field-requirements field) found
              (append prefix (field-path field)) active))))
  (walk (record-interface-fields interface) (record-interface-requirements interface) record)
  (reverse results))

(define (complete-interface-record interface overrides evaluate-default
                                   [evaluate-guard interface-guard-value])
  (unless (record-interface? interface)
    (raise-argument-error 'interface-record "record-interface?" interface))
  (unless (hash? overrides)
    (raise-argument-error 'interface-record "hash?" overrides))
  (define (put-path record path value)
    (define name (car path))
    (if (null? (cdr path))
        (let ([earlier (hash-ref record name #f)])
          (hash-set record name
                    (if (and (hash? earlier) (hash? value))
                        (merge-records earlier value)
                        value)))
        (hash-set record name
                  (put-path (let ([current (hash-ref record name #f)])
                              (if (hash? current) current (hasheq)))
                            (cdr path) value))))
  (define (merge-records old changes)
    (for/fold ([result old]) ([(name value) (in-hash changes)])
      (define earlier (hash-ref result name #f))
      (when (and (hash-has-key? result name)
                 (hash? value) (not (hash? earlier)))
        (error 'interface-record "nested update needs a record at ~a" name))
      (hash-set result name
                (if (and (hash? earlier) (hash? value))
                    (merge-records earlier value)
                    value))))
  (define (active? field values)
    (define guard (record-field-guard field))
    (if guard (eq? (evaluate-guard guard values) #t) #t))
  (define (defaults-for fields [values (hasheq)])
    (for/fold ([record (hasheq)])
              ([field (in-list fields)] #:when (active? field values))
      (cond [(record-field-default field)
             (put-path record (field-path field)
                       (evaluate-default (record-field-default field)))]
            [(and (record-field-children field) (record-field-required? field))
             (define existing (path-value values (field-path field)))
             (define nested (defaults-for (record-field-children field)
                                          (if (hash? existing) existing (hasheq))))
             (if (zero? (hash-count nested)) record
                 (put-path record (field-path field) nested))]
            [else record])))
  (define (complete fields values)
    (define combined
      (let loop ([current values])
        (define next (merge-records (defaults-for fields current) current))
        (if (equal? next current) current (loop next))))
    (for/fold ([record combined])
              ([field (in-list fields)]
               #:when (and (record-field-children field) (active? field combined)))
      (define found (path-value record (field-path field)))
      (cond [(eq? found absent) record]
            [(not (hash? found))
             (error 'interface-record "nested field ~a needs a record" (record-field-name field))]
            [else (put-path record (field-path field)
                            (complete (record-field-children field) found))])))
  (complete (record-interface-fields interface) overrides))

(define (interface-record interface overrides evaluate-default
                          [evaluate-guard interface-guard-value])
  (define result (complete-interface-record interface overrides evaluate-default evaluate-guard))
  (define requirements (interface-requirement-results interface result evaluate-guard))
  (define missing
    (remove-duplicates
     (append (missing-interface-fields interface result evaluate-guard)
             (append* (map requirement-result-missing
                           (filter (lambda (check) (eq? (requirement-result-outcome check) 'violated)) requirements))))))
  (unless (null? missing)
    (error 'interface-record "~a is missing field~a ~a"
           (record-interface-name interface)
           (if (= (length missing) 1) "" "s")
           (string-join (map symbol->string missing) ", ")))
  (define pending (undetermined-interface-fields interface result evaluate-guard))
  (unless (null? pending)
    (error 'interface-record "~a has undetermined conditional requirements: ~a"
           (record-interface-name interface)
           (string-join (map symbol->string pending) ", ")))
  (for ([check (in-list requirements)])
    (case (requirement-result-outcome check)
      [(violated)
       (error 'interface-record "~a does not satisfy value requirement ~s"
              (record-interface-name interface) (requirement-result-expression check))]
      [(undetermined)
       (error 'interface-record "~a has an undetermined value requirement ~s"
              (record-interface-name interface) (requirement-result-expression check))]))
  result)
