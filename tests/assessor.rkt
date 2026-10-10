#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/port
         racket/runtime-path
         "../assessor.rkt"
         "../workflow-model.rkt"
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
    "workflow \"Chain check\"\nimplements \"requirement.rkt\" as chain "
    "[provide third by \"report\"]\n")
   (lambda (_interface method)
     (define findings (assessment-findings (assess-file method)))
     (check-equal? (map finding-kind findings)
                   '(missing-part missing-part affected-part affected-part affected-part))
     (check-not-false (member '(first second third) (map finding-chain findings)))))

  (with-sources
   "#lang sciencelogo\ninterface \"Parts\" [version \"1\" require a]\n"
   (string-append
    "#lang sciencelogo\n"
    "workflow \"Parts check\"\nimplements \"requirement.rkt\" as p "
    "[provide a by \"one\" provide a by \"two\" "
    "provide extra by \"three\"]\n")
   (lambda (_interface method)
     (check-equal? (map finding-kind (assessment-findings (assess-file method)))
                   '(duplicate-part unknown-part))))

  (with-sources
   "#lang sciencelogo\ninterface \"Parts\" [version \"1\" require a]\n"
   (string-append
    "#lang sciencelogo\n"
    "workflow \"Missing file\"\nimplements \"absent.rkt\" as p []\n")
   (lambda (_interface method)
     (check-equal? (map finding-kind (assessment-findings (assess-file method)))
                   '(missing-interface-file))))

  (with-sources
   "#lang sciencelogo\ninterface \"Parts\" [require a]\n"
   "#lang sciencelogo\nworkflow \"Invalid\"\n\n"
   (lambda (interface _method)
     (check-exn #rx"exactly one version" (lambda () (parse-sciencelogo-file interface)))))

  (with-sources
   (string-append
    "#lang sciencelogo\n"
    "interface \"Parts\" [version \"1\" require a affects a absent]\n")
   "#lang sciencelogo\nworkflow \"Invalid\"\n\n"
   (lambda (interface _method)
     (check-exn #rx"impact references unknown part"
                (lambda () (parse-sciencelogo-file interface)))))

  (with-sources
   "#lang sciencelogo\ninterface \"Parts\" [version \"1\" require a]\n"
   (string-append
    "#lang sciencelogo\n"
    "workflow \"Invalid\"\nimplements \"/absolute.rkt\" as p []\n")
   (lambda (_interface method)
     (check-exn #rx"interface file path must be relative"
                (lambda () (parse-sciencelogo-file method)))))

  (with-sources
   ""
   (string-append
    "#lang sciencelogo\n"
    "workflow \"Pendulum method\"\n"
    "  must do compare-periods\n"
    "  stage \"Prepare\"\n"
    "  do [do prepare]\n"
    "  to prepare [do compare-periods]\n"
    "  to compare-periods []\n"
    "\n")
   (lambda (_interface method)
     (define result (assess-file method))
     (check-equal? (map condition-check-outcome (assessment-checks result))
                   '(satisfied))
     (check-equal? (assessment-findings result) '())
     (check-equal? (length (condition-check-evidence
                            (first (assessment-checks result)))) 1)
     (define model (read-workflow-model method))
     (define bad-condition
       (struct-copy condition-model (first (workflow-model-conditions model))
                    [target (workflow-model-id model)]))
     (check-equal?
      (map finding-kind
           (assessment-findings
            (assess-workflow
             (struct-copy workflow-model model [conditions (list bad-condition)]))))
      '(invalid-condition))))

  (with-sources
   ""
   (string-append
    "#lang sciencelogo\n"
    "workflow \"Unused procedure\"\n"
    "  must do compare-periods\n"
    "  to unused [do compare-periods]\n"
    "  to compare-periods []\n"
    "\n")
   (lambda (_interface method)
     (define result (assess-file method))
     (check-equal? (map condition-check-outcome (assessment-checks result))
                   '(violated))
     (check-equal? (map finding-kind (assessment-findings result))
                   '(missing-required-call))
     (check-regexp-match #rx"Required call to compare-periods is absent"
                         (with-output-to-string
                           (lambda () (render-assessment result))))))

  (with-sources
   ""
   (string-append
    "#lang sciencelogo\n"
    "workflow \"Unknown requirement\"\nmust do absent\n")
   (lambda (_interface method)
     (check-exn #rx"unknown procedure absent in must do"
                (lambda () (parse-sciencelogo-file method)))))

  (with-sources
   ""
   (string-append
    "#lang sciencelogo\n"
    "workflow \"Stage requirement\"\n"
    "must stages in order [\"Prepare\" \"Time\"]\n"
    "stage \"Prepare\"\n"
    "stage \"Optional\"\n"
    "stage \"Time\"\n")
   (lambda (_interface method)
     (define result (assess-file method))
     (check-equal? (map condition-check-outcome (assessment-checks result))
                   '(satisfied))
     (check-equal? (length (condition-check-evidence
                            (first (assessment-checks result)))) 2)
     (check-equal? (assessment-findings result) '())))

  (with-sources
   ""
   (string-append
    "#lang sciencelogo\n"
    "must stages in order [\"Prepare\" \"Time\"]\n"
    "stage \"Time\"\n"
    "stage \"Prepare\"\n")
   (lambda (_interface method)
     (define result (assess-file method))
     (check-equal? (map finding-kind (assessment-findings result))
                   '(required-stage-order))
     (check-equal? (condition-check-gap (first (assessment-checks result)))
                   'stage-order)))

  (with-sources
   ""
   (string-append
    "#lang sciencelogo\n"
    "must stages in order [\"Prepare\" \"Time\"]\n"
    "stage \"Prepare\"\n"
    "do [stage \"Time\"]\n")
   (lambda (_interface method)
     (define result (assess-file method))
     (check-equal? (map finding-kind (assessment-findings result))
                   '(missing-required-stage))
     (check-regexp-match #rx"Required stage \"Time\" is absent"
                         (with-output-to-string
                           (lambda () (render-assessment result))))))

  (with-sources
   ""
   (string-append
    "#lang sciencelogo\n"
    "must stages in order [\"Prepare\" \"Time\"]\n"
    "stage \"Prepare\"\n"
    "stage \"Time\"\n")
   (lambda (_interface method)
     (define model (read-workflow-model method))
     (define prepare (first (workflow-model-stages model)))
     (define repeated
       (struct-copy stage-model prepare
                    [id (string-append (stage-model-id prepare) "/copy")]))
     (define containment
       (findf (lambda (relation)
                (and (eq? (relation-model-kind relation) 'contains)
                     (equal? (relation-model-to relation)
                             (stage-model-id prepare))))
              (workflow-model-relations model)))
     (define result
       (assess-workflow
        (struct-copy workflow-model model
                     [stages (cons repeated (workflow-model-stages model))]
                     [relations
                      (cons (struct-copy relation-model containment
                                         [to (stage-model-id repeated)])
                            (workflow-model-relations model))])))
     (check-equal? (map finding-kind (assessment-findings result))
                   '(ambiguous-required-stage)))))
