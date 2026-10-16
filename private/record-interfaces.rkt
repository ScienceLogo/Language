#lang racket/base

(require racket/list racket/string)

(provide (struct-out record-interface)
         resolve-record-interfaces
         interface-record
         missing-interface-fields)

;; A field is (cons name default-expression-or-#f). The caller evaluates
;; defaults in its own value environment before constructing a record.
(struct record-interface (name fields) #:transparent)

;; Declarations map interface names to reader datums: (extends Parent) and
;; (interface-field field default-or-#f). Resolution permits forward references.
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
                (define own
                  (for/list ([part (in-list parts)]
                             #:when (eq? (car part) 'interface-field))
                    (cons (cadr part) (caddr part))))
                (define own-names (map car own))
                (define inherited '())
                (for ([part (in-list parts)] #:when (eq? (car part) 'extends))
                  (define parent (visit (cadr part) name))
                  (for ([field (in-list (record-interface-fields parent))]
                        #:unless (memq (car field) own-names))
                    (define existing (assoc (car field) inherited))
                    (cond
                      [(not existing)
                       (set! inherited (append inherited (list field)))]
                      [(not (equal? (cdr existing) (cdr field)))
                       (fail name
                             (format "conflicting inherited field ~a in ~a; declare it explicitly"
                                     (car field) name))])))
                (define result
                  (record-interface (symbol->string name) (append inherited own)))
                (hash-remove! active name)
                (hash-set! resolved name result)
                result)))
  (for ([name (in-list (sort (hash-keys declarations) string<?
                             #:key symbol->string))])
    (visit name))
  resolved)

(define (missing-interface-fields interface record)
  (unless (record-interface? interface)
    (raise-argument-error 'missing-interface-fields "record-interface?" interface))
  (define (present? value path)
    (and (hash? value)
         (hash-has-key? value (car path))
         (or (null? (cdr path))
             (present? (hash-ref value (car path)) (cdr path)))))
  (for/list ([field (in-list (record-interface-fields interface))]
             #:unless (present? record
                                (map string->symbol
                                     (string-split (symbol->string (car field)) "."))))
    (car field)))

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
  (define defaults
    (for/fold ([record (hasheq)])
              ([field (in-list (record-interface-fields interface))]
               #:when (cdr field))
      (put-path record
                (map string->symbol
                     (string-split (symbol->string (car field)) "."))
                (evaluate-default (cdr field)))))
  (define result (merge-records defaults overrides))
  (define missing (missing-interface-fields interface result))
  (unless (null? missing)
    (error 'interface-record "~a is missing field~a ~a"
           (record-interface-name interface)
           (if (= (length missing) 1) "" "s")
           (string-join (map symbol->string missing) ", ")))
  result)
