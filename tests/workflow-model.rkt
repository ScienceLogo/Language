#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/port
         racket/runtime-path
         racket/system
         "../assessor.rkt"
         "../workflow-model.rkt")

(define-runtime-path pendulum "../examples/pendulum-method.rkt")
(define-runtime-path complete "../examples/meta-assessor/method.rkt")
(define-runtime-path incomplete "../examples/meta-assessor/missing-impact.rkt")
(define-runtime-path assessor-interface
  "../examples/meta-assessor/requirements/assessor.rkt")

(define (relation? kind from to relations)
  (for/or ([relation (in-list relations)])
    (and (eq? (relation-model-kind relation) kind)
         (equal? (relation-model-from relation) from)
         (equal? (relation-model-to relation) to))))

(define (with-tagged-library use)
  (define directory (make-temporary-file "sciencelogo-model-~a" 'directory))
  (define library (build-path directory "library"))
  (define method-path (build-path directory "method.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (make-directory library)
      (call-with-output-file (build-path library "library.rkt")
        (lambda (out)
          (display "#lang sciencelogo\nlibrary \"timing\" [to plan [stage \"Prepare\" output \"Time ten swings.\"]]\n"
                   out)))
      (define (git . args)
        (define status
          (parameterize ([current-output-port (open-output-string)]
                         [current-error-port (open-output-string)])
            (apply system*/exit-code (find-executable-path "git")
                   "-C" (path->string library) args)))
        (unless (zero? status) (error 'with-tagged-library "Git command failed")))
      (git "init" "--initial-branch=main")
      (git "add" "library.rkt")
      (git "-c" "user.name=ScienceLogo Tests"
           "-c" "user.email=tests@example.invalid"
           "commit" "--quiet" "-m" "Add timing library")
      (git "tag" "v1")
      (call-with-output-file method-path
        (lambda (out)
          (fprintf out
                   (string-append
                    "#lang sciencelogo\n"
                    "workflow \"Plan a timing\"\n"
                    "import ~s at \"v1\" as timing\n"
                    "import ~s at \"v1\" as second\n"
                    "do timing.plan as plan print plan\n"
                    "do second.plan as another print another\n")
                   (format "file://~a" (path->string library))
                   (format "file://~a" (path->string library)))))
      (use method-path))
    (lambda () (delete-directory/files directory))))

(module+ test
  (define staged-source (make-temporary-file "sciencelogo-stages-~a.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file staged-source
        (lambda (out)
          (display
           (string-append
            "#lang sciencelogo\n"
            "workflow \"Stage links\"\n"
            "  stage \"Prepare\"\n"
            "  do make-plan as plan\n"
            "  to make-plan [output \"ready\"]\n"
            "  stage \"Review\"\n"
            "  print plan\n"
            "\n")
           out))
        #:exists 'truncate)
      (define staged (read-workflow-model staged-source))
      (define stages (workflow-model-stages staged))
      (define activities (workflow-model-activities staged))
      (define call (findf (lambda (a) (eq? (activity-model-kind a) 'call)) activities))
      (define display-step
        (findf (lambda (a) (eq? (activity-model-kind a) 'print)) activities))
      (define links (workflow-model-relations staged))
      (check-equal? (map stage-model-name stages) '("Prepare" "Review"))
      (check-equal? (stage-model-parent (first stages)) (workflow-model-id staged))
      (check-true (relation? 'contains (stage-model-id (first stages))
                             (activity-model-id call) links))
      (check-true (relation? 'contains (stage-model-id (second stages))
                             (activity-model-id display-step) links))
      (check-true (relation? 'precedes (activity-model-id call)
                             (activity-model-id display-step) links))
      (check-true (relation? 'depends-on (activity-model-id display-step)
                                (activity-model-id call) links))
      (check-equal? (assessment-findings (assess-workflow staged)) '()))
    (lambda () (delete-file staged-source))))

(module+ test
  (define method (read-workflow-model pendulum))
  (check-equal? (workflow-model-title method)
                "How does length affect a pendulum's period?")
  (check-equal? (workflow-model-revision method)
                (workflow-model-revision (read-workflow-model pendulum)))
  (define copied-method (make-temporary-file "sciencelogo-method-~a.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (copy-file pendulum copied-method #t)
      (check-equal? (workflow-model-revision method)
                    (workflow-model-revision
                     (read-workflow-model copied-method))))
    (lambda () (delete-file copied-method)))
  (check-equal? (map procedure-model-name (workflow-model-procedures method))
                '(make-timing-plan))
  (define procedure (first (workflow-model-procedures method)))
  (define sequence
    (findf (lambda (activity) (eq? (activity-model-kind activity) 'sequence))
           (workflow-model-activities method)))
  (define call
    (findf (lambda (activity) (eq? (activity-model-kind activity) 'call))
           (workflow-model-activities method)))
  (define display-step
    (findf (lambda (activity) (eq? (activity-model-kind activity) 'print))
           (workflow-model-activities method)))
  (define plan (first (workflow-model-items method)))
  (define relations (workflow-model-relations method))
  (check-equal? (item-model-name plan) 'plan)
  (check-equal? (item-model-producer plan) (activity-model-id call))
  (check-true (positive? (source-ref-line (activity-model-source call))))
  (check-true
   (relation? 'defines (workflow-model-id method) (procedure-model-id procedure)
              relations))
  (check-true
   (relation? 'contains (activity-model-id sequence) (activity-model-id call)
              relations))
  (check-true
   (relation? 'invokes (activity-model-id call) (procedure-model-id procedure)
              relations))
  (check-true
   (relation? 'precedes (activity-model-id call) (activity-model-id display-step)
              relations))
  (check-true
   (relation? 'produces (activity-model-id call) (item-model-id plan)
              relations))
  (check-true
   (relation? 'uses (activity-model-id display-step) (item-model-id plan)
              relations))
  (check-true
   (relation? 'depends-on (activity-model-id display-step)
              (activity-model-id call) relations))
  (check-equal? (assessment-findings (assess-workflow method)) '())

  (define requirement (read-interface-model assessor-interface))
  (check-equal?
   (map condition-model-target (interface-model-conditions requirement))
   '(parse resolve-libraries check-interfaces trace-impacts report))
  (check-equal? (length (interface-model-relations requirement)) 4)
  (define complete-assessment (assess-file complete))
  (check-equal? (map condition-check-outcome
                     (assessment-checks complete-assessment))
                '(satisfied satisfied satisfied satisfied satisfied))
  (define incomplete-assessment (assess-file incomplete))
  (check-equal? (map condition-check-outcome
                     (assessment-checks incomplete-assessment))
                '(satisfied satisfied satisfied violated satisfied))
  (check-equal? (map finding-outcome
                     (assessment-findings incomplete-assessment))
                '(violated undetermined))
  (define missing (first (assessment-findings incomplete-assessment)))
  (check-equal? (finding-condition missing)
                (condition-check-condition
                 (fourth (assessment-checks incomplete-assessment))))
  (check-true (source-ref? (condition-model-source
                            (fourth (interface-model-conditions requirement)))))

  (define bad-relation
    (relation-model 'uses (workflow-model-id method)
                    (procedure-model-id procedure)
                    (source-ref "constructed test" 1 0 1)))
  (define malformed
    (struct-copy workflow-model method
                 [relations (append relations (list bad-relation))]))
  (define malformed-findings
    (assessment-findings (assess-workflow malformed)))
  (check-equal? (map finding-kind malformed-findings)
                '(invalid-relation))
  (check-equal? (finding-outcome (first malformed-findings)) 'violated)

  (define call-containment
    (findf (lambda (relation)
             (and (eq? (relation-model-kind relation) 'contains)
                  (equal? (relation-model-to relation) (activity-model-id call))))
           relations))
  (define wrong-parent
    (struct-copy relation-model call-containment
                 [from (workflow-model-id method)]))
  (check-equal?
   (map finding-kind
        (assessment-findings
         (assess-workflow
          (struct-copy workflow-model method
                       [relations (cons wrong-parent
                                        (remove call-containment relations))]))))
   '(invalid-relation))
  (check-equal?
   (map finding-kind
        (assessment-findings
         (assess-workflow
          (struct-copy workflow-model method
                       [relations (remove call-containment relations)]))))
   '(missing-containment))
  (check-equal?
   (map finding-kind
        (assessment-findings
         (assess-workflow
          (struct-copy workflow-model method
                       [relations (cons call-containment relations)]))))
   '(duplicate-containment)))

(module+ test
  (with-tagged-library
   (lambda (path)
     (define imported (read-workflow-model path))
     (define library-import (first (workflow-model-imports imported)))
     (define library-procedure (first (workflow-model-procedures imported)))
     (define call
       (findf (lambda (activity) (eq? (activity-model-kind activity) 'call))
              (workflow-model-activities imported)))
     (check-regexp-match #px"^[0-9a-f]{40}$"
                         (import-model-commit library-import))
     (check-equal? (procedure-model-name library-procedure) 'timing.plan)
     (check-equal? (map stage-model-name (workflow-model-stages imported))
                   '("timing.Prepare" "second.Prepare"))
     (check-equal? (length (remove-duplicates
                            (map stage-model-id (workflow-model-stages imported))))
                   2)
     (check-true
      (relation? 'invokes (activity-model-id call)
                 (procedure-model-id library-procedure)
                 (workflow-model-relations imported)))
     (check-equal? (assessment-findings (assess-workflow imported)) '()))))
