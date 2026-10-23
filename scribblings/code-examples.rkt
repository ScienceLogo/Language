#lang racket/base

(require racket/string scribble/base scribble/core scribble/html-properties
         "../normalize.rkt")

(provide code-example)

(define (flow name blocks [properties '()])
  (nested-flow (style name (cons (alt-tag "div") properties)) blocks))

(define (panel syntax source)
  (flow "code-example-panel"
        (list (paragraph (style "code-example-label" '())
                         (list (case syntax [(compact) "Compact"] [(verbose) "Verbose"]
                                     [else "Shared syntax"])))
              (verbatim source))
        (list (attributes `((data-syntax . ,(symbol->string syntax)))))))

;; Wrappers give fragments the same grammatical context as their manual page.
;; They are removed before rendering; examples are translated, never executed.
(define (code-example #:kind [kind 'commands] . content)
  (define source (string-trim (apply string-append content) "\n"))
  (define-values (prefix suffix)
    (case kind
      [(commands) (values "" "")]
      [(interface) (values "interface Documentation-example [\n" "\n]")]
      [(expressions) (values "print [\n" "\n]")]
      [else (raise-argument-error 'code-example "(or/c 'commands 'interface 'expressions)" kind)]))
  (define (convert target)
    (define converted
      (normalized-source-text
       (translate-source (string-append prefix source suffix)
                         #:to target #:source 'documentation-example)))
    (substring converted (string-length prefix) (- (string-length converted) (string-length suffix))))
  (define compact (convert 'compact))
  (define verbose (convert 'verbose))
  (flow "code-example"
        (if (string=? compact verbose)
            (list (panel 'shared compact))
            (list (panel 'compact compact) (panel 'verbose verbose)))))
