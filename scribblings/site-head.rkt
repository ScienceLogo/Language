#lang racket/base

(require net/base64
         racket/file
         racket/runtime-path
         scribble/core
         scribble/html-properties
         "code-examples.rkt")

(provide page-style (all-from-out "code-examples.rkt"))

(define-runtime-path favicon-path "../assets/favicon.svg")
(define-runtime-path search-script-path "site-search.js")
(define-runtime-path examples-script-path "code-examples.js")
(define-runtime-path examples-style-path "code-examples.css")

(define favicon-data-url
  (string-append "data:image/svg+xml;base64,"
                 (bytes->string/utf-8
                  (base64-encode (file->bytes favicon-path) #""))))

(define (page-style #:toc? [toc? #f])
  (style #f
         (append (if toc? '(toc) '())
                 (list (js-addition search-script-path)
                       (js-addition examples-script-path)
                       (css-addition examples-style-path)
                       (head-extra
                        `(link ((rel "icon")
                                (type "image/svg+xml")
                                (sizes "any")
                                (href ,favicon-data-url))))))))
