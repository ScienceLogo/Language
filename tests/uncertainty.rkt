#lang racket/base

(require rackunit racket/file racket/port
         "../private/reader.rkt" "../workflow-model.rkt")

(define (with-source content use)
  (define path (make-temporary-file "sciencelogo-uncertainty-~a.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file path
        (lambda (out) (display content out))
        #:exists 'truncate)
      (use path))
    (lambda () (delete-file path))))

(define (run content)
  (with-source content
    (lambda (path)
      (with-output-to-string (lambda () (dynamic-require path #f))))))

(define (read-method content)
  (with-source content read-workflow-model))

(module+ test
  (define example
    (string-append
     "#lang sciencelogo\n"
     "period = 2.01 u [declared = [timing-resolution = [type = \"epistemic\" estimate = 0.02 unit = \"s\"] trial-spread = [type = [\"aleatory\" \"epistemic\"] estimate = unknown]] omitted = [reaction-delay = [reason = \"not estimated\"]]]\n"
     "print period\n"
     "print period.u.declared.timing-resolution.estimate\n"
     "print period.u.declared.trial-spread.type.[2]\n"
     "copy = period\n"
     "period.u.declared.timing-resolution.estimate = 0.03\n"
     "print copy.u.declared.timing-resolution.estimate\n"
     "print period.u.declared.timing-resolution.estimate\n"
     "derived = (period / 2) u [declared = [method = [description = \"review calculation\"]]]\n"
     "print derived\n"
     "print derived.u.declared.method.description\n"))
  (check-equal? (run example)
                "2.01\n0.02\nepistemic\n0.02\n0.03\n1.005\nreview calculation\n")
  (with-source example
    (lambda (path)
      (define method (read-workflow-model path))
      (check-equal? (length (workflow-model-activities method)) 11)
      (define syntax (parse-sciencelogo-file path))
      (check-true (regexp-match? #rx"uncertain" (format "~s" syntax)))
      (check-true (regexp-match? #rx"timing-resolution" (format "~s" syntax)))))
  (check-equal? (run "#lang sciencelogo\nx = 10 u []\nprint x.u.declared\nprint x.u.omitted\n")
                "[]\n[]\n")
  (check-equal?
   (run "#lang sciencelogo\ntrial = [duration = 2 u [declared = [clock = []]] unit = \"s\"] u []\nprint trial.duration.u.declared.clock\nprint trial.[duration unit]\nready = true u []\nif ready [print \"yes\"]\n")
   "[]\n[duration = 2 unit = \"s\"]\nyes\n")
  (check-equal? (run "#lang sciencelogo\nx = 10 u []\nx.u = [omitted = [drift = [reason = \"unchecked\"]]]\nprint x.u.omitted.drift.reason\n")
                "unchecked\n")
  (check-equal? (run "#lang sciencelogo\nx = 10 u []\ny = x + 1\nprint y\nx = 12\nprint x\n")
                "11\n12\n")
  (define (reject-read pattern content)
    (check-exn pattern (lambda () (read-method content))))
  (define (reject-run pattern content)
    (check-exn pattern (lambda () (run content))))
  (reject-read #rx"u fields must be declared or omitted"
               "#lang sciencelogo\nx = 10 u [spread = []]\n")
  (reject-read #rx"u declared needs named entries"
               "#lang sciencelogo\nx = 10 u [declared = [1 2]]\n")
  (reject-read #rx"a u source needs named fields"
               "#lang sciencelogo\nx = 10 u [declared = [drift = 0.1]]\n")
  (reject-read #rx"a value can have only one u description"
               "#lang sciencelogo\nx = 10 u [] u []\n")
  (reject-run #rx"this value has no u description"
              "#lang sciencelogo\nx = 10\nprint x.u\n")
  (reject-run #rx"update a qualified value"
              "#lang sciencelogo\nx = 10 u []\nx += 1\n")
  (reject-run #rx"this value has no u description"
              "#lang sciencelogo\nx = 10 u []\nx = 11\nprint x.u\n"))
