#lang racket/base

(require rackunit racket/file racket/list racket/path racket/port racket/system
         "../private/reader.rkt" "../workflow-model.rkt" "../assessor.rkt")

(define (with-source body use)
  (define path (make-temporary-file "sciencelogo-identifiers-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\n" body) path #:exists 'truncate))
    (lambda () (use path))
    (lambda () (delete-file path))))
(define (run body)
  (with-source body (lambda (path) (with-output-to-string (lambda () (dynamic-require path #f))))))
(define protocol "interface Protocol [version \"1\" must [measurement]]\n")

(module+ test
  (define method
    (string-append
     "workflow \"Human-readable workflow title\"\n"
     "about \"Names are identifiers; this explanation is text.\"\n"
     protocol
     "interface timing_shape [must [period = 2 unit = \"seconds\"]]\n"
     "must stages in order [prepare measure]\n"
     "measure implement Protocol.measurement\n"
     "stage prepare\ntrial = timing_shape.[]\n"
     "stage measure\ntrial implement timing_shape\nprint trial.unit\n"))
  (check-equal? (run method) "seconds\n")
  (with-source method
    (lambda (path)
      (define model (read-workflow-model path))
      (check-equal? (workflow-model-title model) "Human-readable workflow title")
      (check-equal? (description-model-text (workflow-model-description model))
                    "Names are identifiers; this explanation is text.")
      (check-equal? (map stage-model-name (workflow-model-stages model)) '("prepare" "measure"))
      (check-equal? (map mapping-model-kind (workflow-model-mappings model)) '(stage value))
      (check-equal? (mapping-model-subject (first (workflow-model-mappings model)))
                    (stage-model-id (second (workflow-model-stages model))))
      (check-equal? (assessment-findings (assess-file path)) '())
      (define mapping (findf (lambda (form) (eq? (node-kind form) 'implement))
                            (node-children (parse-sciencelogo-tree-file path))))
      (check-equal? (node-kind (first (node-children mapping))) 'stage-reference)))

  ;; Quoted strings never declare or reference a named language component.
  (for ([invalid (list "stage \"measure\""
                       "interface \"Timing\" []"
                       "library \"tools\" []"
                       "to \"measure\" []"
                       "do \"measure\""
                       "\"measure\" implement Protocol.measurement"
                       "must stages in order [\"prepare\" measure]")])
    (with-source invalid
      (lambda (path) (check-exn exn:fail:read? (lambda () (parse-sciencelogo-file path))))))
  (for* ([kind '("stage" "interface" "library")]
         [name '("2" "2-trials" "outer.inner" ":input" "if")])
    (with-source (format "~a ~a []" kind name)
      (lambda (path) (check-exn #rx"unquoted.*name" (lambda () (parse-sciencelogo-file path))))))
  (check-equal? (run "library tools [to greeting [output \"Hello, world!\"]]\n") "")
  (with-source "interface Timing [version \"v1\" must [unit = \"seconds\"]]\n"
    (lambda (path) (check-equal? (interface-model-name (read-interface-model path)) "Timing")))

  ;; Identifier spelling is case-sensitive; the conventions remain optional.
  (check-equal? (run "stage Measure_period\nvalue = \"stage \\\"measure\\\"\"\nprint value\n")
                "stage \"measure\"\n")
  (with-source (string-append protocol "stage Measure\nmeasure implement Protocol.measurement\n")
    (lambda (path) (check-exn #rx"unknown result measure" (lambda () (read-workflow-model path)))))
  (check-exn #rx"unknown result measure" (lambda () (run "stage measure\nprint measure\n")))
  (check-exn #rx"unknown procedure measure" (lambda () (run "stage measure\ndo measure\n")))

  ;; Declaration contexts still distinguish functions from stages. A bare
  ;; implementation target must have one meaning in its visible context.
  (check-equal? (run "to measure [output 2]\nstage measure\ndo measure as result\nprint result\n") "2\n")
  (for ([body (list "to measure []\nstage measure\nmeasure implement Protocol.measurement\n"
                    "stage measure\nmeasure = []\nmeasure implement Protocol.measurement\n"
                    "performer measure []\nstage measure\nmeasure implement Protocol.measurement\n"
                    "interface measure [field]\nstage measure\nmeasure implement Protocol.measurement\n")])
    (with-source (string-append protocol body)
      (lambda (path) (check-exn #rx"ambiguous implementation target measure"
                                (lambda () (read-workflow-model path))))))
  (check-equal?
   (run "interface Data [must [value]]\nto inspect :measure [:measure implement Data output :measure]\nstage measure\ndo inspect [value = 2] as result\nprint result.value\n")
   "2\n")

  ;; A pinned library, its included method, and its private dependency all
  ;; resolve stage references from declarations before names are qualified.
  (define directory (make-temporary-file "sciencelogo-identifier-repos-~a" 'directory))
  (define (git repo . args)
    (unless (zero? (parameterize ([current-output-port (open-output-string)]
                                  [current-error-port (open-output-string)])
                     (apply system*/exit-code (find-executable-path "git") "-C" (path->string repo) args)))
      (error 'identifier-tests "Git fixture failed")))
  (define (tag repo)
    (git repo "add" ".")
    (git repo "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid"
         "commit" "--quiet" "-m" "Define identifier fixture")
    (git repo "tag" "v1"))
  (dynamic-wind
    void
    (lambda ()
      (define base (build-path directory "base"))
      (define wrapper (build-path directory "wrapper"))
      (define workflow (build-path directory "workflow"))
      (for ([repo (list base wrapper workflow)])
        (make-directory repo)
        (git repo "init" "--initial-branch=main"))
      (display-to-file (string-append "#lang sciencelogo\nlibrary tools [\n" protocol "include \"method.rkt\"]\n")
                       (build-path base "library.rkt"))
      (display-to-file "#lang sciencelogo\nto inspect [measure implement Protocol.measurement stage measure]\n"
                       (build-path base "method.rkt"))
      (tag base)
      (display-to-file
       (format "#lang sciencelogo\nlibrary wrapper [import ~s at \"v1\" as inner\n~ato inspect [inner.measure implement Protocol.measurement]]\n"
               (format "file://~a" base) protocol)
       (build-path wrapper "library.rkt"))
      (tag wrapper)
      (define entry (build-path workflow "entry.rkt"))
      (define imports
        (format "import ~s at \"v1\" as tools\nimport ~s at \"v1\" as outer\n"
                (format "file://~a" base) (format "file://~a" wrapper)))
      (display-to-file "#lang sciencelogo\nstage local-measure\nlocal-measure implement tools.Protocol.measurement\n"
                       (build-path workflow "stage.rkt"))
      (display-to-file
       (string-append "#lang sciencelogo\n" imports
                      "tools.measure implement tools.Protocol.measurement\n"
                      "include \"stage.rkt\"\ndo tools.inspect\ndo outer.inspect\n") entry)
      (check-equal? (with-output-to-string (lambda () (dynamic-require entry #f))) "")
      (define model (read-workflow-model entry))
      (check-equal? (map stage-model-name (workflow-model-stages model))
                    '("tools.measure" "outer.inner.measure" "local-measure"))
      (check-true (andmap (lambda (mapping) (eq? (mapping-model-kind mapping) 'stage))
                          (workflow-model-mappings model)))
      (check-not-false
       (member (stage-model-id (second (workflow-model-stages model)))
               (map mapping-model-subject (workflow-model-mappings model))))
      (check-equal? (map import-model-library-name (workflow-model-imports model)) '("tools" "wrapper" "tools"))
      (display-to-file
       (string-append "#lang sciencelogo\n" imports
                      "tools = [measure = []]\ntools.measure implement tools.Protocol.measurement\n")
       entry #:exists 'truncate)
      (check-exn #rx"ambiguous implementation target tools.measure" (lambda () (read-workflow-model entry))))
    (lambda () (delete-directory/files directory))))
