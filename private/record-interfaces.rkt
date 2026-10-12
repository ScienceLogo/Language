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
  (if (hash? record)
      (for/list ([field (in-list (record-interface-fields interface))]
                 #:unless (hash-has-key? record (car field)))
        (car field))
      (map car (record-interface-fields interface))))

(define (interface-record interface overrides evaluate-default)
  (unless (record-interface? interface)
    (raise-argument-error 'interface-record "record-interface?" interface))
  (unless (hash? overrides)
    (raise-argument-error 'interface-record "hash?" overrides))
  (define defaults
    (for/fold ([record (hasheq)])
              ([field (in-list (record-interface-fields interface))]
               #:when (cdr field))
      (hash-set record (car field) (evaluate-default (cdr field)))))
  (define result
    (for/fold ([record defaults]) ([(name value) (in-hash overrides)])
      (hash-set record name value)))
  (define missing (missing-interface-fields interface result))
  (unless (null? missing)
    (error 'interface-record "~a is missing field~a ~a"
           (record-interface-name interface)
           (if (= (length missing) 1) "" "s")
           (string-join (map symbol->string missing) ", ")))
  result)
