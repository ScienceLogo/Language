#lang racket/base

(require "normalize.rkt")

(provide (all-from-out "normalize.rkt"))

(module+ main
  (require racket/cmdline racket/file)
  (define target #f)
  (define path
    (command-line
     #:program "sciencelogo/translate"
     #:once-each
     [("--to") spelling "Output syntax: compact or verbose"
      (set! target (cond [(equal? spelling "compact") 'compact]
                         [(equal? spelling "verbose") 'verbose]
                         [else (raise-user-error 'sciencelogo/translate
                                                 "--to must be compact or verbose")]))]
     #:args (source-file)
     source-file))
  (unless target
    (raise-user-error 'sciencelogo/translate "choose --to compact or --to verbose"))
  (display (normalized-source-text
            (translate-source (file->string path) #:to target #:source path))))
