#lang racket/base

(require rackunit racket/file racket/list racket/port racket/runtime-path racket/system
         "../assessor.rkt" "../workflow-model.rkt" "../private/reader.rkt")

(define-runtime-path example "../examples/value-requirements.rkt")
(define declaration
  "interface \"Timing\" [must [swing-count > 10 swing-height unit == \"seconds\"]]\n")

(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-values-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"Values\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))

(define (run body)
  (with-source body
    (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))

(define (outcomes body)
  (with-source body
    (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))

(module+ test
  (check-equal?
   (run (string-append declaration
                        "trial = Timing.[swing-count = 20 swing-height = 0.1 unit = \"seconds\"]\n"
                        "print trial.swing-count\n"))
   "20\n")
  (check-exn #rx"does not satisfy value requirement"
             (lambda () (run (string-append declaration
                                            "trial = Timing.[swing-count = 10 swing-height = 0.1 unit = \"seconds\"]\n"))))
  (check-exn #rx"does not satisfy value requirement"
             (lambda () (run (string-append declaration
                                            "trial = Timing.[swing-count = 20 swing-height = 0.1 unit = \"minutes\"]\n"))))
  (check-exn #rx"missing field.*unit"
             (lambda () (run (string-append declaration "trial = Timing.[swing-count = 20 swing-height = 0.1]\n"))))
  (check-exn #rx"missing field.*swing-height"
             (lambda () (run (string-append declaration "trial = Timing.[swing-count = 20 unit = \"seconds\"]\n"))))
  (check-exn #rx"undetermined value requirement"
             (lambda () (run (string-append declaration
                                            "trial = Timing.[swing-count = unknown swing-height = unknown unit = \"seconds\"]\n"))))
  (check-equal? (outcomes (string-append declaration
                                        "trial = [swing-count = 20 swing-height = unknown unit = \"seconds\"]\ntrial implement Timing\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append declaration
                                        "trial = [swing-count = 10 swing-height = 0.1 unit = \"seconds\"]\ntrial implement Timing\n"))
                '(violated))
  (check-equal? (outcomes (string-append declaration
                                        "trial = [swing-count = unknown swing-height = 0.1 unit = \"seconds\"]\ntrial implement Timing\n"))
                '(undetermined))

  ;; Boolean expressions and adjacent bare entries share the same must group.
  (check-equal?
   (run (string-append "interface \"Range\" [must [count > 10 and count < 100 note not rejected]]\n"
                        "trial = Range.[count = 20 note = \"hand timed\" rejected = false]\nprint trial.count\n"))
   "20\n")
  (check-equal?
   (run "interface \"Approved\" [must [status == \"reviewed\" or status == \"published\"]]\ntrial = Approved.[status = \"reviewed\"]\nprint trial.status\n")
   "reviewed\n")
  (check-equal?
   (run "interface \"Answer\" [must [answer == [result = \"yes\"]]]\ntrial = Answer.[answer = [result = \"yes\"]]\nprint trial.answer.result\n")
   "yes\n")
  (check-exn #rx"missing field.*limit"
             (lambda () (run "interface \"Bounded\" [must [count > limit]]\ntrial = Bounded.[count = 20]\n")))

  ;; Defaults remain overridable; an equality requirement supplies no default.
  (check-equal? (run "interface \"Defaults\" [must [unit = \"seconds\"]]\ntrial = Defaults.[unit = \"minutes\"]\nprint trial.unit\n")
                "minutes\n")
  (check-equal?
   (run (string-append "interface \"Base\" [must [unit = \"seconds\"]]\n"
                        "interface \"Fixed\" [extends Base must [unit == \"seconds\"]]\n"
                        "trial = Fixed.[]\nprint trial.unit\n"))
   "seconds\n")
  (check-exn #rx"does not satisfy value requirement"
             (lambda () (run (string-append "interface \"Base\" [must [unit = \"seconds\"]]\n"
                                            "interface \"Fixed\" [extends Base must [unit == \"seconds\"]]\n"
                                            "trial = Fixed.[unit = \"minutes\"]\n"))))

  ;; Nested requirements use local field names and the existing dotted paths.
  (check-equal?
   (run (string-append "interface \"Nested\" [must [timing [must [count > 10 unit == \"seconds\"]]]]\n"
                        "trial = Nested.[timing = [count = 20 unit = \"seconds\"]]\n"
                        "part = Nested.timing.[count = 30 unit = \"seconds\"]\nprint part.count\n"))
   "30\n")
  (check-equal?
   (run (string-append "interface \"Nested\" [must [timing.count > 10]]\n"
                        "trial = Nested.[timing = [count = 20]]\nprint trial.timing.count\n"))
   "20\n")

  ;; The established conditional syntax governs value requirements as well.
  (define conditional
    (string-append "interface \"Conditional\" [must [method] "
                   "if method == \"automatic\" [must [count > 10]] "
                   "else if method == \"video\" [must [frame-rate >= 25]] "
                   "else [must [observer]]]\n"))
  (check-equal? (run (string-append conditional "trial = Conditional.[method = \"manual\" observer = \"researcher\"]\nprint trial.method\n"))
                "manual\n")
  (check-exn #rx"does not satisfy value requirement"
             (lambda () (run (string-append conditional "trial = Conditional.[method = \"video\" frame-rate = 10]\n"))))

  ;; Equality comparisons use == throughout the language; = retains assignment.
  (check-equal?
   (run (string-append "count = 0\nwhile count != 2 [count += 1]\n"
                        "if count == 2 [print \"matched\"]\n"
                        "repeat [count += 1] until count == 3\n"
                        "same = count == 3\nprint same\nprint [(count == 3)]\n"
                        "to equals :a :b [output :a == :b]\ndo equals 3 3 as answer\nprint answer\n"))
   "matched\ntrue\n[true]\ntrue\n")
  (check-equal? (run "to check :condition [output :condition]\ncount = 10\ndo check count == 10 as answer\nprint answer\n")
                "true\n")
  (check-exn exn:fail:read? (lambda () (run "if 1 = 1 [print true]\n")))

  (with-source
   (string-append declaration "stage \"Measure\"\n\"Measure\" implement Timing\n")
   (lambda (file)
     (define model (read-workflow-model file))
     (define interface (mapping-model-interface (first (workflow-model-mappings model))))
     (check-equal?
      (map condition-model-evidence
           (filter (lambda (condition) (eq? (condition-model-kind condition) 'value-requirement))
                   (interface-model-conditions interface)))
      '((compare > ((result swing-count) (literal 10)))
        (compare == ((result unit) (literal "seconds")))))
     (check-equal? (map condition-check-outcome (assessment-checks (assess-workflow model)))
                   '(satisfied satisfied satisfied undetermined undetermined))))

  ;; A requirement-only entry can be referenced by the existing mapping syntax.
  (with-source
   (string-append declaration "count = 20\ncount implement Timing.swing-count\n")
   (lambda (file)
     (check-equal? (mapping-model-part (first (workflow-model-mappings (read-workflow-model file))))
                   'swing-count)))
  ;; Combining interfaces retains requirements inherited through both paths.
  (with-source
   (string-append "interface \"Base\" [must [count > 10]]\n"
                  "interface \"Left\" [extends Base]\ninterface \"Right\" [extends Base]\n"
                  "interface \"Combined\" [extends Left extends Right must [count < 100]]\n"
                  "stage \"Measure\"\n\"Measure\" implement Combined\n")
   (lambda (file)
     (define method (read-workflow-model file))
     (define interface (mapping-model-interface (first (workflow-model-mappings method))))
     (define ids (map condition-model-id (interface-model-conditions interface)))
     (check-equal? (length ids) (length (remove-duplicates ids)))
     (check-equal?
      (length (filter (lambda (condition) (eq? (condition-model-kind condition) 'value-requirement))
                      (interface-model-conditions interface))) 2)))

  (define directory (make-temporary-file "sciencelogo-required-library-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (display-to-file (string-append "#lang sciencelogo\n" declaration) (build-path directory "requirement.rkt"))
      (display-to-file
       (string-append "#lang sciencelogo\nlibrary \"timing\" [" declaration "]\n")
       (build-path directory "library.rkt"))
      (define (git . args)
        (define code (parameterize ([current-output-port (open-output-string)]
                                    [current-error-port (open-output-string)])
                       (apply system*/exit-code (find-executable-path "git")
                              "-C" (path->string directory) args)))
        (unless (zero? code) (error 'value-requirement-library "Git failed: ~a" args)))
      (git "init" "--initial-branch=main")
      (git "add" "library.rkt" "requirement.rkt")
      (git "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid"
           "commit" "--quiet" "-m" "Add value requirements")
      (git "tag" "v1")
      (define body
        (format (string-append "import ~s at \"v1\" as timing\n"
                               "trial = timing.Timing.[swing-count = 20 swing-height = 0.1 unit = \"seconds\"]\n"
                               "trial implement timing.Timing\nprint trial.unit\n")
                (format "file://~a" directory)))
      (check-equal? (run body) "seconds\n")
      (check-equal? (outcomes body) '(satisfied))
      (define file (build-path directory "workflow.rkt"))
      (display-to-file
       (string-append "#lang sciencelogo\ntrial = [swing-count = 10 swing-height = 0.1 unit = \"seconds\"]\n"
                      "trial implement \"requirement.rkt\"\n") file)
      (check-equal? (map condition-check-outcome (assessment-checks (assess-file file))) '(violated)))
    (lambda () (delete-directory/files directory)))
  (check-equal? (assessment-findings (assess-file example)) '()))
