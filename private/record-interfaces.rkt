#lang racket/base

(require racket/list racket/string)

(provide (struct-out record-interface)
         (struct-out record-field)
         resolve-record-interfaces
         interface-reference-root
         resolve-interface-reference
         interface-record
         missing-interface-fields)

;; The caller evaluates defaults in its own value environment.
(struct record-interface (name fields) #:transparent)
(struct record-field (name default required? children) #:transparent)

;; Declarations map interface names to reader datums: (extends Parent) and
;; (interface-field name default-or-#f required? children-or-#f).
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
                        (record-field-children group))
                       (substring text (string-length (symbol->string
                                                        (record-field-name group))))))]))))

(define (declaration-fields parts)
  (for/list ([part (in-list parts)] #:when (eq? (car part) 'interface-field))
    (record-field (cadr part) (caddr part) (cadddr part)
                  (and (list-ref part 4) (declaration-fields (list-ref part 4))))))

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
                (for ([part (in-list parts)] #:when (eq? (car part) 'extends))
                  (define parent (visit (cadr part) name))
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
                  (record-interface (symbol->string name) (append inherited own)))
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

(define (missing-interface-fields interface record)
  (unless (record-interface? interface)
    (raise-argument-error 'missing-interface-fields "record-interface?" interface))
  (define (walk fields value [prefix ""])
    (append*
     (for/list ([field (in-list fields)])
       (define name (string-append prefix (symbol->string (record-field-name field))))
       (define found (path-value value (field-path field)))
       (cond [(eq? found absent)
              (if (record-field-required? field) (list (string->symbol name)) '())]
             [(record-field-children field)
              (if (hash? found)
                  (walk (record-field-children field) found (string-append name "."))
                  (list (string->symbol name)))]
             [else '()]))))
  (walk (record-interface-fields interface) record))

(define (interface-record interface overrides evaluate-default)
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
  (define (defaults-for fields)
    (for/fold ([record (hasheq)])
              ([field (in-list fields)])
      (cond [(record-field-default field)
             (put-path record (field-path field)
                       (evaluate-default (record-field-default field)))]
            [(and (record-field-children field) (record-field-required? field))
             (define nested (defaults-for (record-field-children field)))
             (if (zero? (hash-count nested)) record
                 (put-path record (field-path field) nested))]
            [else record])))
  (define (complete fields values)
    (define combined (merge-records (defaults-for fields) values))
    (for/fold ([record combined])
              ([field (in-list fields)] #:when (record-field-children field))
      (define found (path-value record (field-path field)))
      (cond [(eq? found absent) record]
            [(not (hash? found))
             (error 'interface-record "nested field ~a needs a record" (record-field-name field))]
            [else (put-path record (field-path field)
                            (complete (record-field-children field) found))])))
  (define result (complete (record-interface-fields interface) overrides))
  (define missing (missing-interface-fields interface result))
  (unless (null? missing)
    (error 'interface-record "~a is missing field~a ~a"
           (record-interface-name interface)
           (if (= (length missing) 1) "" "s")
           (string-join (map symbol->string missing) ", ")))
  result)
