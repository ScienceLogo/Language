#lang racket/base

(provide source-file-url source-directory-url)

(define source-ref (or (getenv "SCIENCELOGO_DOC_COMMIT") "main"))
(define repository-url "https://github.com/ScienceLogo/Language")

(define (source-file-url path)
  (string-append repository-url "/blob/" source-ref "/" path))

(define (source-directory-url path)
  (string-append repository-url "/tree/" source-ref "/" path))
