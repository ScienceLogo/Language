#lang racket/base

(require "git-fixture.rkt"
         rackunit racket/file racket/list racket/path racket/port racket/system
         "../private/reader.rkt" "../workflow-model.rkt" "../assessor.rkt")

(define (with-source source use)
  (define path (make-temporary-file "sciencelogo-naming-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\n" source) path #:exists 'truncate))
    (lambda () (use path))
    (lambda () (delete-file path))))
(define (run source)
  (with-source source (lambda (path) (with-output-to-string (lambda () (dynamic-require path #f))))))
(define (outcomes source)
  (with-source source (lambda (path) (map condition-check-outcome (assessment-checks (assess-file path))))))

(module+ test
  ;; Case and separator conventions never determine the kind of a name.
  (check-equal?
   (run "interface timing_shape [must [period]]\ninterface TimingShape [must [unit]]\nfirst_value = timing_shape.[period = 2]\nSecondValue = TimingShape.[unit = \"seconds\"]\nprint first_value.period print SecondValue.unit\n")
   "2\nseconds\n")
  (check-exn #rx"unknown result timing" (lambda () (run "interface Timing [must [period]]\nvalue = timing.[period = 2]")))

  (define directory (make-temporary-file "sciencelogo-naming-repos-~a" 'directory))
  (with-git-fixture
    void
    (lambda ()
      (define base (build-path directory "base"))
      (define wrapper (build-path directory "wrapper"))
      (make-directory base)
      (make-directory wrapper)
      (define (git repo . arguments)
        (unless (zero? (parameterize ([current-output-port (open-output-string)]
                                     [current-error-port (open-output-string)])
                         (apply system*/exit-code (find-executable-path "git") "-C" (path->string repo) arguments)))
          (error 'naming-tests "Git fixture failed")))
      (define (tag repo version)
        (git repo "add" ".")
        (git repo "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid"
             "commit" "--quiet" "-m" "Define naming fixture")
        (git repo "tag" version))
      (git base "init" "--initial-branch=main")
      (git wrapper "init" "--initial-branch=main")
      (define declaration "interface timing_shape [must [period is number details [must [unit = \"seconds\"]]]]\n")
      (display-to-file (string-append "#lang sciencelogo\n" declaration) (build-path base "types.rkt"))
      (display-to-file
       "#lang sciencelogo\nlibrary TimingTools [include \"types.rkt\" to EchoValue :input_value [output ((:input_value))]]\n"
       (build-path base "library.rkt"))
      (tag base "v1")
      (define prefix (format "import ~s at \"v1\" as TimingTools\n" (format "file://~a" base)))
      (define setup (string-append prefix "trial = (TimingTools.timing_shape).[period = 2]\n"))
      (check-equal? (run (string-append setup "do TimingTools.EchoValue (trial.period) as ReturnedValue\nprint ReturnedValue\nprint trial.details.unit\n")) "2\nseconds\n")
      (check-equal? (run (string-append prefix "print (TimingTools.timing_shape.[period = 2]) is TimingTools.timing_shape\n")) "true\n")
      (check-equal? (run (string-append prefix "trial = TimingTools.timing_shape.details.[]\nprint trial.unit\nprint trial is TimingTools.timing_shape.details\n")) "seconds\ntrue\n")
      (check-equal? (outcomes (string-append setup "trial implement TimingTools.timing_shape\ntrial.details implement TimingTools.timing_shape.details\n")) '(satisfied satisfied))
      (with-source
       (string-append prefix "stage Document\nDocument implement TimingTools.timing_shape.details\n")
       (lambda (path)
         (define mapping (first (workflow-model-mappings (read-workflow-model path))))
         (check-equal? (mapping-model-part mapping) 'details)
         (check-equal? (interface-model-name (mapping-model-interface mapping)) "TimingTools.timing_shape")))
      (check-equal? (run (string-append prefix "interface local_shape [extends TimingTools.timing_shape]\ntrial = local_shape.[period = 2]\nprint trial.details.unit\n")) "seconds\n")
      (check-equal? (run (string-append prefix "interface experiment_shape [must [timing = (unknown) TimingTools.timing_shape.details]]\ntrial = experiment_shape.[]\ntrial.timing = [unit = \"minutes\"]\nprint trial is experiment_shape\n")) "true\n")

      ;; References in included workflow files resolve after imports assemble.
      (define included (build-path wrapper "included.rkt"))
      (display-to-file "#lang sciencelogo\ntrial = TimingTools.timing_shape.[period = 2]\nprint trial.period\n" included)
      (define entry (build-path wrapper "workflow.rkt"))
      (display-to-file (string-append "#lang sciencelogo\n" prefix "include \"included.rkt\"\n") entry)
      (check-equal? (with-output-to-string (lambda () (dynamic-require entry #f))) "2\n")

      ;; Library bodies can use a lowercase interface imported through an alias.
      (for ([alias '("InnerTools" "inner_tools")] [revision '("capital" "lower")])
        (display-to-file
         (format "#lang sciencelogo\nlibrary wrapper [import ~s at \"v1\" as ~a interface public_shape [must [period is number]] to make_trial [value = (~a.timing_shape).[period = 2] output ((value))]]\n"
                 (format "file://~a" base) alias alias)
         (build-path wrapper "library.rkt") #:exists 'truncate)
        (tag wrapper revision)
        (define wrapper-prefix (format "import ~s at ~s as OuterTools\n" (format "file://~a" wrapper) revision))
        (check-equal? (run (string-append wrapper-prefix "do OuterTools.make_trial as trial\nprint trial.period\n")) "2\n")
        ;; A capitalized private dependency alias grants no extra access.
        (for ([body (list (format "print [period = 2] is OuterTools.~a.timing_shape\n" alias)
                          (format "shape = OuterTools.~a.timing_shape\n" alias)
                          (format "interface Check [must [timing = unknown OuterTools.~a.timing_shape]]\n" alias))])
          (check-exn #rx"dependency is private"
                     (lambda () (run (string-append wrapper-prefix body)))))))
    (lambda () (delete-directory/files directory))))
