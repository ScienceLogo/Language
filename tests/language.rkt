#lang racket/base

(require rackunit
         racket/file
         racket/port)

(define (with-source source use)
  (define path (make-temporary-file "sciencelogo-~a.rkt"
                                    #:base-dir (current-directory)))
  (call-with-output-file path
    (lambda (out) (display source out))
    #:exists 'truncate)
  (dynamic-wind
    void
    (lambda () (use path))
    (lambda () (delete-file path))))

(define (output-of source)
  (with-source source
    (lambda (path)
      (with-output-to-string
        (lambda () (dynamic-require path #f))))))

(module+ test
  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "investigate \"Plant growth\" [\n"
     "  do [do first print \"last\"]\n"
     "  to first [print \"first\" do second]\n"
     "  to second [print \"second\"]\n"
     "]\n"))
   "first\nsecond\nlast\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "#| outer #| nested |# comment |#\n"
     "investigate \"Notes\" [\n"
     "  ; the brackets in the string are ordinary text\n"
     "  print \"height [cm]\"\n"
     "]\n"))
   "height [cm]\n")

  (define output-before-error (open-output-string))
  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"unknown procedure missing" (exn-message e))))
   (lambda ()
     (parameterize ([current-output-port output-before-error])
       (output-of
        (string-append
         "#lang sciencelogo\n"
         "investigate \"Invalid\" [print \"must not run\" do missing]\n")))))
  (check-equal? (get-output-string output-before-error) "")

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"duplicate procedure observe" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "investigate \"Invalid\" [to observe [] to observe []]\n"))))

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"recursive call" (exn-message e))))
   (lambda ()
     (output-of
     (string-append
       "#lang sciencelogo\n"
       "investigate \"Invalid\" [to first [do second] to second [do first]]\n"))))

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"expected ] before end of file" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "investigate \"Invalid\" [do [print \"incomplete\"]\n"))))

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "investigate \"Plant labels\" [\n"
     "  do make-note \"Plant B\" as note\n"
     "  print note\n"
     "  to make-note :plant [\n"
     "    do echo :plant as inner\n"
     "    output inner\n"
     "  ]\n"
     "  to echo :item [output :item]\n"
     "]\n"))
   "Plant B\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "investigate \"Observation day\" [\n"
     "  do choose-day \"Bean plant\" \"Monday\" as day\n"
     "  print day\n"
     "  to choose-day :plant :day [\n"
     "    print :plant\n"
     "    do [output :day]\n"
     "  ]\n"
     "]\n"))
   "Bean plant\nMonday\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "investigate \"Nested results\" [\n"
     "  do echo \"outer\" as outer\n"
     "  do [print outer do echo \"first\" as local print local]\n"
     "  do [do echo \"second\" as local print local]\n"
     "  print outer\n"
     "  to echo :value [output :value]\n"
     "]\n"))
   "outer\nfirst\nsecond\nouter\n")

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"duplicate result outer" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "investigate \"Invalid\" [\n"
       "  do echo \"outer\" as outer\n"
       "  do [do echo \"inner\" as outer]\n"
       "  to echo :value [output :value]\n"
       "]\n"))))

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"wrong number of inputs for echo" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "investigate \"Invalid\" [do echo to echo :item [output :item]]\n"))))

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"unknown result note" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "investigate \"Invalid\" [\n"
       "  do [do echo \"inside\" as note]\n"
       "  print note\n"
       "  to echo :item [output :item]\n"
       "]\n"))))

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"procedure no-result has no output" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "investigate \"Invalid\" [\n"
       "  do no-result as note\n"
       "  to no-result [print \"not returned\"]\n"
       "]\n")))))
