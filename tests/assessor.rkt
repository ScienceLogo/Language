#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/port
         racket/runtime-path
         "../assessor.rkt"
         "../private/reader.rkt")

(define-runtime-path complete-example "../examples/meta-assessor/method.rkt")
(define-runtime-path incomplete-example "../examples/meta-assessor/missing-impact.rkt")

(define (with-sources interface-text method-text use)
  (define directory (make-temporary-file "sciencelogo-assessor-~a" 'directory))
  (define interface-path (build-path directory "requirement.rkt"))
  (define method-path (build-path directory "method.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file interface-path
        (lambda (out) (display interface-text out)))
      (call-with-output-file method-path
        (lambda (out) (display method-text out)))
      (use interface-path method-path))
    (lambda () (delete-directory/files directory))))

(module+ test
  (define complete (assess-file complete-example))
  (check-equal? (assessment-findings complete) '())
  (check-equal? (assessed-interface-version
                 (first (assessment-interfaces complete)))
                "0.1")
  (check-regexp-match #rx"No structural issues found"
                      (with-output-to-string (lambda () (render-assessment complete))))

  (define incomplete (assess-file incomplete-example))
  (check-equal? (map finding-kind (assessment-findings incomplete))
                '(missing-part affected-part))
  (check-equal? (map finding-chain (assessment-findings incomplete))
                '((trace-impacts) (trace-impacts report)))

  (with-sources
   (string-append
    "#lang sciencelogo\n"
    "interface \"Chain\" [version \"1\" require first require second "
    "require third affects first second affects second third]\n")
   (string-append
    "#lang sciencelogo\n"
    "investigate \"Chain check\" [implements \"requirement.rkt\" as chain "
    "[provide third by \"report\"]]\n")
   (lambda (_interface method)
     (define findings (assessment-findings (assess-file method)))
     (check-equal? (map finding-kind findings)
                   '(missing-part missing-part affected-part affected-part affected-part))
     (check-not-false (member '(first second third) (map finding-chain findings)))))

  (with-sources
   "#lang sciencelogo\ninterface \"Parts\" [version \"1\" require a]\n"
   (string-append
    "#lang sciencelogo\n"
    "investigate \"Parts check\" [implements \"requirement.rkt\" as p "
    "[provide a by \"one\" provide a by \"two\" "
    "provide extra by \"three\"]]\n")
   (lambda (_interface method)
     (check-equal? (map finding-kind (assessment-findings (assess-file method)))
                   '(duplicate-part unknown-part))))

  (with-sources
   "#lang sciencelogo\ninterface \"Parts\" [version \"1\" require a]\n"
   (string-append
    "#lang sciencelogo\n"
    "investigate \"Missing file\" [implements \"absent.rkt\" as p []]\n")
   (lambda (_interface method)
     (check-equal? (map finding-kind (assessment-findings (assess-file method)))
                   '(missing-interface-file))))

  (with-sources
   "#lang sciencelogo\ninterface \"Parts\" [require a]\n"
   "#lang sciencelogo\ninvestigate \"Invalid\" []\n"
   (lambda (interface _method)
     (check-exn #rx"exactly one version" (lambda () (parse-sciencelogo-file interface)))))

  (with-sources
   (string-append
    "#lang sciencelogo\n"
    "interface \"Parts\" [version \"1\" require a affects a absent]\n")
   "#lang sciencelogo\ninvestigate \"Invalid\" []\n"
   (lambda (interface _method)
     (check-exn #rx"impact references unknown part"
                (lambda () (parse-sciencelogo-file interface)))))

  (with-sources
   "#lang sciencelogo\ninterface \"Parts\" [version \"1\" require a]\n"
   (string-append
    "#lang sciencelogo\n"
    "investigate \"Invalid\" [implements \"/absolute.rkt\" as p []]\n")
   (lambda (_interface method)
     (check-exn #rx"interface file path must be relative"
                (lambda () (parse-sciencelogo-file method))))))
