#lang racket/base

(require rackunit racket/file racket/list racket/port racket/runtime-path racket/system
         "../assessor.rkt" "../workflow-model.rkt" "../private/reader.rkt")

(define-runtime-path example "../examples/protocol-mapping.rkt")

(define protocol
  (string-append
   "interface \"Protocol\" [version \"1\" must [measurement documentation [must [uncertainty] notes]] "
   "appendix [must [reason] notes]]\n"))

(define (with-workflow body use)
  (define directory (make-temporary-file "sciencelogo-mappings-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (unless (zero? (parameterize ([current-output-port (open-output-string)]
                                    [current-error-port (open-output-string)])
                        (system*/exit-code (find-executable-path "git")
                                           "-C" (path->string directory) "init" "--initial-branch=main")))
        (error 'with-workflow "could not initialize test repository"))
      (display-to-file (string-append "#lang sciencelogo\n" protocol)
                       (build-path directory "protocol.rkt"))
      (define file (build-path directory "workflow.rkt"))
      (display-to-file (string-append "#lang sciencelogo\ninclude \"protocol.rkt\"\n" body) file)
      (use file))
    (lambda () (delete-directory/files directory))))

(define (outcomes result)
  (map condition-check-outcome (assessment-checks result)))

(module+ test
  ;; A parent mapping covers required children; optional branches remain absent.
  (with-workflow
   (string-append "\"Timing\" implement Protocol.measurement\n"
                  "\"Report\" implement Protocol.documentation\n"
                  "stage \"Timing\"\nstage \"Report\"\n")
   (lambda (file)
     (define method (read-workflow-model file))
     (define mappings (workflow-model-mappings method))
     (check-equal? (map mapping-model-kind mappings) '(stage stage))
     (check-equal? (map mapping-model-subject mappings)
                   (map stage-model-id (workflow-model-stages method)))
     (check-equal? (map mapping-model-part mappings) '(measurement documentation))
     (define interface (mapping-model-interface (first mappings)))
     (check-equal? (interface-model-version interface) "1")
     (check-equal? (interface-model-name interface) "Protocol")
     (check-true (file-exists? (interface-model-source interface)))
     (check-true (andmap source-ref? (map mapping-model-source mappings)))
     (define result (assess-workflow method))
     (check-equal? (assessment-findings result) '())
     (check-equal? (outcomes result) '(satisfied satisfied satisfied))
     (check-equal? (condition-check-evidence (second (assessment-checks result)))
                   (condition-check-evidence (third (assessment-checks result))))))

  ;; Several stages can address the same part, and one stage can address several.
  (with-workflow
   (string-append "stage \"First\"\nstage \"Second\"\n"
                  "\"First\" implement Protocol.measurement\n"
                  "\"Second\" implement Protocol.measurement\n"
                  "\"First\" implement Protocol.documentation\n"
                  "\"Second\" implement Protocol.documentation\n")
   (lambda (file)
     (define result (assess-file file))
     (check-equal? (assessment-findings result) '())
     (check-equal? (outcomes result) '(satisfied satisfied satisfied))
     (check-equal? (map (lambda (check) (length (condition-check-evidence check)))
                        (assessment-checks result)) '(2 2 2))))

  (with-workflow
   "stage \"All\"\n\"All\" implement Protocol\n"
   (lambda (file)
     (check-equal? (assessment-findings (assess-file file)) '())
     (check-equal? (outcomes (assess-file file)) '(satisfied satisfied satisfied))))

  ;; Existing interface extension also preserves inherited protocol targets.
  (with-workflow
   (string-append "interface \"Extended\" [extends Protocol must [review]]\n"
                  "stage \"All\"\n\"All\" implement Extended.measurement\n"
                  "\"All\" implement Extended.documentation\n"
                  "\"All\" implement Extended.review\n")
   (lambda (file)
     (check-equal? (assessment-findings (assess-file file)) '())
     (check-equal? (outcomes (assess-file file)) '(satisfied satisfied satisfied satisfied))))

  ;; A specific child does not claim its siblings. An optional group, if present,
  ;; still has its own requirements.
  (with-workflow
   (string-append "stage \"Timing\"\n\"Timing\" implement Protocol.measurement\n"
                  "\"Timing\" implement Protocol.documentation.notes\n"
                  "\"Timing\" implement Protocol.appendix.notes\n")
   (lambda (file)
     (check-equal? (map finding-part (assessment-findings (assess-file file)))
                   '(documentation.uncertainty appendix.reason))))

  ;; State values and procedures have direct references, not quoted locators.
  (with-workflow
   (string-append
    "performer researcher []\nto measure :value [output :value]\n"
    "measure implement Protocol.measurement\n"
    "stage \"Timing\" by researcher from state [information = [period = 2 u [declared = [timing = [estimate = 0.1]]]]]\n"
    "information.period.u implement Protocol.documentation.uncertainty\n"
    "end stage with state [information = [period = 2 u [declared = [timing = [estimate = 0.1]]]]]\n")
   (lambda (file)
     (define method (read-workflow-model file))
     (define mappings (workflow-model-mappings method))
     (check-equal? (map mapping-model-kind mappings) '(procedure value))
     (check-equal? (mapping-model-subject (first mappings))
                   (procedure-model-id (first (workflow-model-procedures method))))
     (check-equal? (mapping-model-subject (second mappings))
                   '(field-ref u (field-ref period (result information))))
     (check-equal? (mapping-model-parent (second mappings))
                   (stage-model-id (first (workflow-model-stages method))))
     (check-equal? (assessment-findings (assess-workflow method)) '())
     (check-equal? (with-output-to-string (lambda () (dynamic-require file #f))) "")))

  (for ([invalid (in-list
                  (list (cons "\"Missing\" implement Protocol.measurement\n" #rx"unknown stage")
                        (cons "stage \"Timing\"\n\"Timing\" implement Protocol.absent\n"
                              #rx"unknown interface or requirement")
                        (cons "absent implement Protocol.measurement\n" #rx"unknown result")
                        (cons "trial = []\nmust trial implement Protocol\n" #rx"without a must prefix")))])
    (with-workflow (car invalid)
      (lambda (file)
        (check-exn (cdr invalid) (lambda () (read-workflow-model file))))))

  ;; The documented example is itself checked in CI by raco test .
  (check-equal? (assessment-findings (assess-file example)) '())

  ;; Use the established pinned Git import, including mappings inside a library.
  (define directory (make-temporary-file "sciencelogo-mapping-library-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define library (build-path directory "library"))
      (make-directory library)
      (display-to-file
       (string-append
        "#lang sciencelogo\nlibrary \"protocols\" [\n" protocol
        "to inspect [stage \"Inspect\" \"Inspect\" implement Protocol.documentation]\n"
        "to measure [output 2]\n"
        "to plan [measure implement Protocol.measurement output true]\n"
        "to local-record :value [:value implement Protocol.documentation.uncertainty output :value]\n"
        "]\n")
       (build-path library "library.rkt"))
      (define (git . args)
        (define code
          (parameterize ([current-output-port (open-output-string)]
                         [current-error-port (open-output-string)])
            (apply system*/exit-code (find-executable-path "git")
                   "-C" (path->string library) args)))
        (unless (zero? code) (error 'mapping-library "Git failed: ~a" args)))
      (git "init" "--initial-branch=main")
      (git "add" "library.rkt")
      (git "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid"
           "commit" "--quiet" "-m" "Add protocol library")
      (git "tag" "v1")
      (define file (build-path directory "workflow.rkt"))
      (display-to-file
       (format (string-append "#lang sciencelogo\nimport ~s at \"v1\" as prot\n"
                              "stage \"Timing\"\n\"Timing\" implement prot.Protocol.measurement\n"
                              "\"Timing\" implement prot.Protocol.documentation.uncertainty\n")
               (format "file://~a" library)) file)
      (define result (assess-file file))
      (check-equal? (assessment-findings result) '())
      (define method (assessment-method result))
      (check-true (andmap mapping-model? (workflow-model-mappings method)))
      (check-not-false (member 'prot.Protocol
                               (map implementation-model-alias (workflow-model-implementations method))))
      (check-true (andmap (lambda (import) (regexp-match? #px"^[0-9a-f]{40}$" (import-model-commit import)))
                          (workflow-model-imports method))))
    (lambda () (delete-directory/files directory))))
