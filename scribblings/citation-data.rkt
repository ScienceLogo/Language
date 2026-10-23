#lang racket/base

(require racket/list racket/runtime-path racket/string yaml)

(provide project-citation read-citation citation-author-name citation-doi-url citation-text)

(define-runtime-path citation-path "../CITATION.cff")

(define (read-citation path)
  (define data (file->yaml path))
  (unless (hash? data)
    (error 'read-citation "expected a YAML mapping in ~a" path))
  data)

(define project-citation (read-citation citation-path))

(define (citation-author-name person)
  (or (hash-ref person "name" #f)
      (string-join
       (filter (lambda (part) (and (string? part) (not (string=? part ""))))
               (for/list ([key '("given-names" "name-particle" "family-names" "name-suffix")])
                 (hash-ref person key #f)))
       " ")))

(define (citation-doi-url data)
  (define doi (hash-ref data "doi" #f))
  (and doi
       (string-append "https://doi.org/"
                      (regexp-replace #px"^https?://(?:dx[.])?doi[.]org/" doi ""))))

(define (citation-text data)
  (define release-date (hash-ref data "date-released" #f))
  (define year
    (cond [(date? release-date) (number->string (date-year release-date))]
          [release-date (substring release-date 0 4)]
          [else #f]))
  (define version (hash-ref data "version" #f))
  (string-append
   (string-join (map citation-author-name (hash-ref data "authors")) "; ")
   ". " (if year (string-append "(" year "). ") "")
   (hash-ref data "title")
   (if version (string-append " (version " version ")") "")
   " [Software]. "
   (or (citation-doi-url data) (hash-ref data "repository-code"))))
