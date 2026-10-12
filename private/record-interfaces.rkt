#lang racket/base

(require racket/list racket/string)

(provide (struct-out record-interface)
         interface-record
         missing-interface-fields)

;; A field is (cons name default-expression-or-#f). The caller evaluates
;; defaults in its own value environment before constructing a record.
(struct record-interface (name fields) #:transparent)

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
