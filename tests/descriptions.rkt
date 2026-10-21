#lang racket/base

(require rackunit racket/file racket/list racket/path racket/port racket/system
         "../private/reader.rkt" "../workflow-model.rkt" "../assessor.rkt")

(define (with-source body use)
  (define path (make-temporary-file "sciencelogo-about-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\n" body) path #:exists 'truncate))
    (lambda () (use path))
    (lambda () (delete-file path))))
(define (run body)
  (with-source body (lambda (path) (with-output-to-string (lambda () (dynamic-require path #f))))))
(define (outcomes path)
  (map condition-check-outcome (assessment-checks (assess-file path))))

(module+ test
  ;; Markdown is stored as text, with no required template or prose analysis.
  (define summary "Compare the **period** of a pendulum.\n\n- Use ten swings.\n- Note the changing angle.")
  (define method
    (string-append
     "workflow \"Review a timing plan\"\nabout \"" summary "\"\n"
     "stage \"Prepare\"\n; Comments do not interrupt attachment.\nabout \"Prepare the timing plan.\"\n"
     "do make-plan as plan\n"
     "to make-plan [\n  about \"Return a timing plan, with its **purpose**.\"\n"
     "  output \"Time ten swings as the swing gets smaller.\"\n]\n"
     "stage \"Review\" about \"Read the plan.\"\nprint plan\n"))
  (check-equal? (run method) "Time ten swings as the swing gets smaller.\n")
  (with-source method
    (lambda (path)
      (define model (read-workflow-model path))
      (define description (workflow-model-description model))
      (check-equal? (description-model-text description) summary)
      (check-equal? (source-ref-source (description-model-source description)) (path->string path))
      (check-equal? (source-ref-line (description-model-source description)) 3)
      (check-equal? (source-ref-column (description-model-source description)) 0)
      (check-equal? (map (lambda (stage) (description-model-text (stage-model-description stage)))
                        (workflow-model-stages model))
                    '("Prepare the timing plan." "Read the plan."))
      (check-equal? (description-model-text
                     (procedure-model-description (first (workflow-model-procedures model))))
                    "Return a timing plan, with its **purpose**.")
      (check-equal? (map activity-model-kind (workflow-model-activities model)) '(output call print))
      (check-equal? (outcomes path) '())
      (check-equal? (first (third (parse-sciencelogo-file path))) `(about ,summary))
      (check-equal? (second (third (parse-sciencelogo-file path)))
                    '(stage "Prepare" (about "Prepare the timing plan.")))))

  ;; Descriptions are optional, may be empty, and do not introduce a scope.
  (with-source "to identity :value [output :value]\nstage \"Read\"\nvalue = 2\n"
    (lambda (path)
      (define model (read-workflow-model path))
      (check-false (workflow-model-description model))
      (check-false (procedure-model-description (first (workflow-model-procedures model))))
      (check-false (stage-model-description (first (workflow-model-stages model))))))
  (with-source "about \"\"\nto empty [about \"\"]\nstage \"Empty\" about \"\"\ndo empty\n"
    (lambda (path)
      (define model (read-workflow-model path))
      (for ([description (list (workflow-model-description model)
                              (procedure-model-description (first (workflow-model-procedures model)))
                              (stage-model-description (first (workflow-model-stages model))))])
        (check-equal? (description-model-text description) ""))))
  (check-equal? (run "about \"A \\\"quote\\\" and a \\\\ path.\"\nstage \"First\" about \"First.\"\nvalue = 2\nstage \"Second\" about \"Second.\"\nprint value\n")
                "2\n")
  (with-source "about \"A \\\"quote\\\" and a \\\\ path.\"\n"
    (lambda (path)
      (check-equal? (description-model-text (workflow-model-description (read-workflow-model path)))
                    "A \"quote\" and a \\ path.")))

  ;; A description on a nested stage belongs to that stage, not its procedure.
  (with-source "to plan [about \"Method.\" do [stage \"Detail\" about \"Checkpoint.\" print 2]]\ndo plan\n"
    (lambda (path)
      (define model (read-workflow-model path))
      (check-equal? (description-model-text
                     (procedure-model-description (first (workflow-model-procedures model)))) "Method.")
      (check-equal? (description-model-text
                     (stage-model-description (first (workflow-model-stages model)))) "Checkpoint.")))
  (check-equal? (run "to plan [about \"Method.\" do [stage \"Detail\" about \"Checkpoint.\" print 2]]\ndo plan\n") "2\n")

  ;; Paired stage descriptions remain metadata; state-call requirements stay intact.
  (define staged
    (string-append
     "to identity :value [about \"Return the supplied value.\" output :value]\n"
     "performer researcher []\n"
     "stage \"Inspect\" by researcher from state [information = [period = 2]]\n"
     "about \"Inspect the stated period.\"\n"
     "do identity with [value at information.period] into information.copy\n"
     "end stage with state [information = [period = 2 copy = unknown]]\n"))
  (check-equal? (run staged) "")
  (with-source staged
    (lambda (path)
      (define model (read-workflow-model path))
      (check-equal? (description-model-text
                     (stage-model-description (first (workflow-model-stages model))))
                    "Inspect the stated period.")
      (check-equal? (map activity-model-kind (workflow-model-activities model)) '(output state-call))))

  ;; Text cannot silently add a declaration, satisfy a rule, or become a value read.
  (with-source "about \"must do missing; stage \\\"Pretend\\\"\"\nto inspect [about \"output missing\"]\nmust do inspect\n"
    (lambda (path) (check-equal? (outcomes path) '(violated))))
  (with-source "to inspect [about \"A description.\"]\nmust do inspect\ndo inspect\n"
    (lambda (path) (check-equal? (outcomes path) '(satisfied))))

  ;; Placement gives every description one unambiguous owner.
  (for ([body (list "about 2" "to plan [about true]" "stage \"Plan\" about []")])
    (with-source body
      (lambda (path) (check-exn #rx"quoted Markdown text" (lambda () (parse-sciencelogo-file path))))))
  (for ([body (list "about \"One\" about \"Two\""
                    "to plan [about \"One\" about \"Two\"]"
                    "stage \"Plan\" about \"One\" about \"Two\""
                    "stage \"Plan\" from state [] about \"One\" about \"Two\" end stage with state []")])
    (with-source body
      (lambda (path) (check-exn #rx"only one about" (lambda () (parse-sciencelogo-file path))))))
  (for ([body (list "print 2 about \"Late\""
                    "to plan [print 2 about \"Late\"]"
                    "do [about \"Anonymous\"]"
                    "if true [about \"Anonymous\"]"
                    "repeat 1 [about \"Anonymous\"]"
                    "stage \"Plan\" from state [] print 2 about \"Late\" end stage with state []"
                    "library \"plans\" [about \"Library\"]")])
    (with-source body
      (lambda (path) (check-exn #rx"about belongs" (lambda () (parse-sciencelogo-file path))))))
  (for ([body '("about = 2" "to about []" "resource about []")])
    (with-source body
      (lambda (path) (check-exn exn:fail:read? (lambda () (parse-sciencelogo-file path))))))

  ;; Included and imported procedures retain descriptions and original source locations.
  (define directory (make-temporary-file "sciencelogo-about-libraries-~a" 'directory))
  (define (git repo . args)
    (unless (zero? (parameterize ([current-output-port (open-output-string)]
                                  [current-error-port (open-output-string)])
                     (apply system*/exit-code (find-executable-path "git") "-C" (path->string repo) args)))
      (error 'descriptions "Git fixture failed")))
  (dynamic-wind
    void
    (lambda ()
      (define library (build-path directory "library"))
      (define workflow (build-path directory "workflow"))
      (make-directory library)
      (make-directory workflow)
      (git library "init" "--initial-branch=main")
      (git workflow "init" "--initial-branch=main")
      (display-to-file "#lang sciencelogo\nlibrary \"timing\" [include \"methods.rkt\"]\n"
                       (build-path library "library.rkt"))
      (display-to-file "#lang sciencelogo\nto estimate-period :elapsed :swings [about \"Estimate the **period**.\" stage \"Calculate\" about \"Divide by swing count.\" output :elapsed / :swings]\n"
                       (build-path library "methods.rkt"))
      (git library "add" ".")
      (git library "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid"
           "commit" "--quiet" "-m" "Add described method")
      (git library "tag" "v1")
      (define local (build-path workflow "local.rkt"))
      (display-to-file "#lang sciencelogo\nto show :value [about \"Display the value.\" print :value]\n" local)
      (define entry (build-path workflow "entry.rkt"))
      (display-to-file
       (format "#lang sciencelogo\nworkflow \"Timing\"\nabout \"Workflow summary.\"\nimport ~s at \"v1\" as timing\ninclude \"local.rkt\"\ndo timing.estimate-period 20 10 as period\ndo show period\n"
               (format "file://~a" library)) entry)
      (check-equal? (with-output-to-string (lambda () (dynamic-require entry #f))) "2\n")
      (define model (read-workflow-model entry))
      (define procedures (workflow-model-procedures model))
      (define imported (findf (lambda (procedure) (eq? (procedure-model-name procedure) 'timing.estimate-period)) procedures))
      (define included (findf (lambda (procedure) (eq? (procedure-model-name procedure) 'show)) procedures))
      (check-equal? (description-model-text (workflow-model-description model)) "Workflow summary.")
      (check-equal? (description-model-text (procedure-model-description imported)) "Estimate the **period**.")
      (check-equal? (source-ref-line (description-model-source (procedure-model-description imported))) 2)
      (check-equal? (description-model-text (procedure-model-description included)) "Display the value.")
      (check-equal? (source-ref-source (description-model-source (procedure-model-description included))) (path->string local))
      (define stage (first (workflow-model-stages model)))
      (check-equal? (stage-model-name stage) "timing.Calculate")
      (check-equal? (stage-model-parent stage) (procedure-model-id imported))
      (check-equal? (description-model-text (stage-model-description stage)) "Divide by swing count."))
    (lambda () (delete-directory/files directory))))
