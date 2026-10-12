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
(define-runtime-path record-example "../examples/record-interface.rkt")

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

(define (assess-required-method body)
  (with-sources
   ""
   (string-append "#lang sciencelogo\nmust do target\n"
                  body "\nto target []\n")
   (lambda (_interface method) (assess-file method))))

(module+ test
  (check-equal? (assessment-findings (assess-file record-example)) '())

  (with-sources
   "#lang sciencelogo\ninterface \"Timing\" [duration unit = \"seconds\"]\n"
   (string-append
    "#lang sciencelogo\nworkflow \"Check timing\"\n"
    "interface \"Timing\" [duration unit = \"seconds\"]\n"
    "set trial to Timing but [duration = unknown]\n"
    "must trial implement Timing\n"
    "must trial implement \"requirement.rkt\"\n"
    "set other to [duration = 2]\n"
    "must other implement Timing\n"
    "set other to other but [unit = \"minutes\"]\n"
    "must other implement \"requirement.rkt\"\n")
   (lambda (interface method)
     (define result (assess-file method))
     (check-equal? (map condition-check-outcome (assessment-checks result))
                   '(satisfied satisfied violated satisfied))
     (check-equal? (map finding-kind (assessment-findings result))
                   '(missing-field))
     (check-equal? (assessed-interface-revision
                    (second (assessment-interfaces result)))
                   (interface-model-revision (read-interface-model interface)))))

  (with-sources
   "#lang sciencelogo\ninterface \"Timing\" [duration unit]\n"
   (string-append
    "#lang sciencelogo\nworkflow \"Check dynamic record\"\n"
    "to make-record [output [duration = 2 unit = \"seconds\"]]\n"
    "do make-record as trial\n"
    "must trial implement \"requirement.rkt\"\n")
   (lambda (_interface method)
     (define result (assess-file method))
     (check-equal? (map condition-check-outcome (assessment-checks result))
                   '(undetermined))
     (check-equal? (map finding-kind (assessment-findings result))
                   '(unknown-record))))

  (with-sources
   "#lang sciencelogo\ninterface \"Parts\" [require review]\n"
   (string-append
    "#lang sciencelogo\n"
    "set trial to [review = unknown]\n"
    "must trial implement \"requirement.rkt\"\n")
   (lambda (_interface method)
     (check-equal? (map finding-kind (assessment-findings (assess-file method)))
                   '(wrong-interface-kind))))

  (for ([body (in-list
               '("if false [do target]"
                 "if false [do target] else if 2 < 1 [do target]"
                 "if false and unknown [do target]"
                 "if ready of [ready = false] [do target]"
                 "if item 1 of [false true] [do target]"
                 "repeat 0 [do target]"
                 "while false [do target]"
                 "for each item in [] [do target]"
                 "while true [] do target"
                 "do helper to helper [output \"done\" do target]"))])
    (define result (assess-required-method body))
    (check-equal? (condition-check-outcome (first (assessment-checks result)))
                  'violated)
    (check-equal? (map finding-kind (assessment-findings result))
                  '(missing-required-call)))

  (for ([body (in-list
               '("if true [do target]"
                 "if 1 < 2 [do target]"
                 "if 1 + 2 = 3 and not false [do target]"
                 "if true xor false [do target]"
                 "if true or unknown [do target]"
                 "if ready of [ready = true note = \"planned\"] [do target]"
                 "if ready of ([ready = false] but [ready = true]) [do target]"
                 "if item 2 of [false true] [do target]"
                 "if item 2 of [unknown true] [do target]"
                 "if false [do target] else [do target]"
                 "if false [do target] else if 1 < 2 [do target]"
                 "if false [do target] do target"
                 "repeat 2 [do target]"
                 "for each item in [1] [do target]"
                 "for each item in range 0.25 to 1 step 0.25 [do target]"
                 "repeat [do target] until unknown"
                 "do helper to helper [if true [do target]]"))])
    (define result (assess-required-method body))
    (check-equal? (condition-check-outcome (first (assessment-checks result)))
                  'satisfied)
    (check-equal? (assessment-findings result) '()))

  (for ([body (in-list
               '("if unknown [do target]"
                 "if unknown xor true [do target]"
                 "if ready of [ready = unknown] [do target]"
                 "if [value = unknown] = [value = unknown] [do target]"
                 "if item 1 of [unknown true] [do target]"
                 "if unknown [do target] else [do target]"
                 "set condition to true if condition [do target]"
                 "repeat 2 [if unknown [do target]]"))])
    (define result (assess-required-method body))
    (define check (first (assessment-checks result)))
    (check-equal? (condition-check-outcome check) 'undetermined)
    (check-equal? (condition-check-gap check) 'conditional-call)
    (check-equal? (map finding-kind (assessment-findings result))
                  '(conditional-required-call)))

  (define conditional (assess-required-method "if unknown [do target]"))
  (check-regexp-match
   #rx"Required call to target is conditional"
   (with-output-to-string (lambda () (render-assessment conditional)))))

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
     (check-not-exn (lambda () (parse-sciencelogo-file interface)))))

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
     (check-equal? (condition-model-kind
                    (first (workflow-model-conditions model)))
                   'required-call)
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
