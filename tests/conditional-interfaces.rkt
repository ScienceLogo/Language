#lang racket/base

(require rackunit racket/file racket/list racket/port racket/runtime-path racket/system
         "../assessor.rkt" "../workflow-model.rkt" "../private/reader.rkt")

(define-runtime-path example "../examples/conditional-interface.rkt")

(define declaration
  (string-append
   "interface \"Timing\" [version \"1\" must [method]\n"
   " if method == \"automatic\" [must [instrument unit = \"seconds\"]]\n"
   " else if method == \"video\" [must [frame-rate]]\n"
   " else [must [observer]] notes]\n"))

(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-conditional-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"Conditions\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))

(define (output-of body)
  (with-source body
    (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))

(define (outcomes body)
  (with-source body
    (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))

(module+ test
  (check-equal?
   (output-of
    (string-append declaration
                   "auto = Timing.[method = \"automatic\" instrument = \"timer-1\"]\n"
                   "video = Timing.[method = \"video\" frame-rate = 25]\n"
                   "manual = Timing.[method = \"manual\" observer = \"researcher\"]\n"
                   "print auto.unit print video.frame-rate print manual.observer\n"))
   "seconds\n25\nresearcher\n")
  (check-exn #rx"missing field instrument"
             (lambda () (output-of (string-append declaration "trial = Timing.[method = \"automatic\"]\n"))))
  (check-exn #rx"missing field frame-rate"
             (lambda () (output-of (string-append declaration "trial = Timing.[method = \"video\"]\n"))))
  (check-exn #rx"missing field observer"
             (lambda () (output-of (string-append declaration "trial = Timing.[method = \"manual\"]\n"))))
  (check-exn #rx"missing field unit"
             (lambda ()
               (output-of (string-append declaration
                                         "trial = Timing.[method = \"manual\" observer = \"researcher\"]\n"
                                         "print trial.unit\n"))))

  ;; A simple if has no implicit else requirement. The inactive field can still
  ;; be supplied, since the established interface rules allow additional fields.
  (define simple "interface \"Timing\" [must [method] if method == \"automatic\" [must [instrument]]]\n")
  (check-equal? (outcomes (string-append simple "trial = [method = \"manual\"]\ntrial implement Timing\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append simple "trial = [method = \"automatic\"]\ntrial implement Timing\n"))
                '(violated))
  (check-equal? (outcomes (string-append simple "trial = [method = unknown]\ntrial implement Timing\n"))
                '(undetermined))
  (check-equal? (outcomes (string-append simple "trial = [method = unknown instrument = unknown]\ntrial implement Timing\n"))
                '(satisfied))
  (check-exn #rx"undetermined conditional requirements"
             (lambda () (output-of (string-append simple "trial = Timing.[method = unknown]\n"))))

  ;; Conditions use entries of the surrounding named part, including when that
  ;; part is constructed through its dotted interface reference.
  (define nested
    (string-append "interface \"Nested\" [must [setup [must [method] "
                   "if method == \"automatic\" [must [instrument unit = \"seconds\"]]]]]\n"))
  (check-equal?
   (output-of (string-append nested
                             "trial = Nested.[setup = [method = \"automatic\" instrument = \"timer-1\"]]\n"
                             "part = Nested.setup.[method = \"manual\"]\n"
                             "print trial.setup.unit print part.method\n"))
   "seconds\nmanual\n")
  (check-equal?
   (outcomes (string-append nested
                            "trial = [setup = [method = \"automatic\"]]\ntrial implement Nested\n"))
   '(violated))

  ;; Reuse arithmetic, Boolean operators, and dotted access in a condition.
  (check-equal?
   (output-of
    (string-append "interface \"Plan\" [must [timing enabled] "
                   "if enabled and not (timing.repeats < 2) [must [summary = \"compare trials\"]]]\n"
                   "trial = Plan.[timing = [repeats = 3] enabled = true]\nprint trial.summary\n"))
   "compare trials\n")
  (check-equal?
   (output-of
    (string-append "interface \"Plan\" [must [period] "
                   "if period.u.declared.timing.estimate > 0 [must [summary = \"describe uncertainty\"]]]\n"
                   "trial = Plan.[period = 2 u [declared = [timing = [estimate = 0.1]]]]\nprint trial.summary\n"))
   "describe uncertainty\n")

  ;; Defaults can depend on entries declared later in the same interface.
  (check-equal?
   (output-of
    (string-append "interface \"Defaulted\" [if method == \"automatic\" [must [instrument = \"timer-1\"]] "
                   "must [method = \"automatic\"]]\ntrial = Defaulted.[]\nprint trial.instrument\n"))
   "timer-1\n")

  (check-equal?
   (outcomes
    (string-append "interface \"Nested-if\" [must [method calibrated] "
                   "if method == \"automatic\" [if calibrated [must [calibration]]]]\n"
                   "trial = [method = \"automatic\" calibrated = false]\ntrial implement Nested-if\n"
                   "other = [method = \"automatic\" calibrated = true]\nother implement Nested-if\n"))
   '(satisfied violated))

  ;; A link in a false branch remains inspectable but contributes no finding.
  (with-source
   (string-append "interface \"Links\" [must [source result] if false [affects source result]]\n"
                  "stage \"Report\"\n\"Report\" implement Links.result\n")
   (lambda (file)
     (define method (read-workflow-model file))
     (define interface (mapping-model-interface (first (workflow-model-mappings method))))
     (check-true (guarded-relation-model? (first (interface-model-relations interface))))
     (check-equal? (map finding-kind (assessment-findings (assess-workflow method))) '(missing-part))))

  (for ([invalid (in-list
                  (list (cons "interface \"Bad\" [must [method] if missing == true [must [instrument]]]\n"
                              #rx"unknown interface entry missing")
                        (cons "interface \"Bad\" [must [method] if :method [must [instrument]]]\n"
                              #rx"not procedure inputs")
                        (cons "interface \"Bad\" [must [method] if true [version \"2\"]]\n"
                              #rx"version belongs")
                        (cons "interface \"Bad\" [must [method] elseif true [must [instrument]]]\n"
                              #rx"expected")))])
    (with-source (car invalid)
      (lambda (file) (check-exn (cdr invalid) (lambda () (read-workflow-model file))))))

  ;; Conditions and nested scopes survive both inheritance and model creation.
  (with-source
   (string-append declaration "interface \"Extended\" [extends Timing must [review]]\n"
                  "stage \"Measure\"\n\"Measure\" implement Extended\n")
   (lambda (file)
     (define method (read-workflow-model file))
     (define interface (mapping-model-interface (first (workflow-model-mappings method))))
     (define fields (interface-model-conditions interface))
     (check-equal? (map condition-model-target fields) '(method instrument unit frame-rate observer notes review))
     (check-false (condition-model-guard (first fields)))
     (check-equal? (condition-model-guard (second fields)) '(compare == ((result method) (literal "automatic"))))
     (check-not-false (condition-model-guard (fourth fields)))
     (check-not-false (condition-model-guard (fifth fields)))
     (check-equal? (assessment-findings (assess-workflow method)) '())))

  ;; A condition is retained rather than being silently treated as false when
  ;; the structural mapping check has no value with which to resolve it.
  (with-source
   (string-append simple "to describe-method [output unknown]\n"
                  "describe-method implement Timing.method\n")
   (lambda (file)
     (define result (assess-file file))
     (check-equal? (map condition-check-outcome (assessment-checks result)) '(satisfied undetermined))
     (check-equal? (map finding-kind (assessment-findings result)) '(unknown-condition))))

  (check-equal? (assessment-findings (assess-file example)) '())

  ;; Existing pinned library imports carry the conditions without renaming the
  ;; interface's own entry references.
  (define directory (make-temporary-file "sciencelogo-conditional-library-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (display-to-file (string-append "#lang sciencelogo\nlibrary \"timing\" [" declaration "]\n")
                       (build-path directory "library.rkt"))
      (define (git . args)
        (define code (parameterize ([current-output-port (open-output-string)]
                                    [current-error-port (open-output-string)])
                       (apply system*/exit-code (find-executable-path "git")
                              "-C" (path->string directory) args)))
        (unless (zero? code) (error 'conditional-library "Git failed: ~a" args)))
      (git "init" "--initial-branch=main")
      (git "add" "library.rkt")
      (git "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid"
           "commit" "--quiet" "-m" "Add conditional interface")
      (git "tag" "v1")
      (define body
        (format (string-append "import ~s at \"v1\" as timing\n"
                               "trial = timing.Timing.[method = \"automatic\" instrument = \"timer-1\"]\n"
                               "trial implement timing.Timing\nprint trial.unit\n")
                (format "file://~a" directory)))
      (check-equal? (output-of body) "seconds\n")
      (check-equal? (outcomes body) '(satisfied)))
    (lambda () (delete-directory/files directory))))
