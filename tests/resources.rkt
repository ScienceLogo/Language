#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/path
         racket/port
         "../assessor.rkt"
         "../private/reader.rkt"
         "../workflow-model.rkt")

(define (with-source source use)
  (define path (make-temporary-file "sciencelogo-resource-~a.rkt"))
  (dynamic-wind
    (lambda ()
      (call-with-output-file path (lambda (out) (display source out))
        #:exists 'truncate))
    (lambda () (use path))
    (lambda () (delete-file path))))

(define (reject pattern source)
  (with-source source
    (lambda (path)
      (check-exn
       (lambda (e)
         (and (exn:fail:read? e)
              (regexp-match? pattern (exn-message e))))
       (lambda () (parse-sciencelogo-file path))))))

(define (related? kind activity resource model)
  (for/or ([relation (in-list (workflow-model-relations model))])
    (and (eq? (relation-model-kind relation) kind)
         (equal? (relation-model-from relation) (activity-model-id activity))
         (equal? (relation-model-to relation) (resource-model-id resource)))))

(define storage-dir (make-temporary-file "sciencelogo-storage-~a" 'directory))
(dynamic-wind
  void
  (lambda ()
    (define external-file (build-path storage-dir "timings.csv"))
    (define source
      (format
       (string-append
        "#lang sciencelogo\n"
        "workflow \"Trace timing data\"\n"
        "resource timings [path = ~s kind = \"table\"]\n"
        "elapsed = timings.elapsed\n"
        "timings.period = elapsed\n"
        "print elapsed\n"
        "performer researcher [kind = \"human\"]\n"
        "stage \"Inspect\" by researcher from state [information = [elapsed = unknown]]\n"
        "information.elapsed = timings.elapsed\n"
        "timings.checked = information.elapsed\n"
        "end stage with state [information = [elapsed = unknown]]\n")
       (path->string external-file)))
    (with-source source
      (lambda (path)
        (check-equal?
         (with-output-to-string (lambda () (dynamic-require path #f)))
         "unknown\n")
        (check-false (file-exists? external-file))
        (define model (read-workflow-model path))
        (define resource (first (workflow-model-resources model)))
        (check-equal? (resource-model-name resource) 'timings)
        (check-equal? (length (workflow-model-resources model)) 1)
        (define actions
          (filter (lambda (activity)
                    (memq (activity-model-kind activity)
                          '(assignment path-assignment)))
                  (workflow-model-activities model)))
        (check-equal? (length actions) 4)
        (check-true (related? 'reads-from (first actions) resource model))
        (check-true (related? 'writes-to (second actions) resource model))
        (check-true (related? 'reads-from (third actions) resource model))
        (check-true (related? 'writes-to (fourth actions) resource model))
        (define performer (first (workflow-model-performers model)))
        (for ([activity (in-list (drop actions 2))])
          (check-true
           (for/or ([relation (in-list (workflow-model-relations model))])
             (and (eq? (relation-model-kind relation) 'performed-by)
                  (equal? (relation-model-from relation)
                          (activity-model-id activity))
                  (equal? (relation-model-to relation)
                          (performer-model-id performer))))))
        (check-equal? (activity-model-details (second actions))
                      '(path-assignment (field-ref period (result timings))
                                        (result elapsed)))
        (check-equal? (assessment-findings (assess-workflow model)) '()))))
  (lambda () (delete-directory/files storage-dir)))

(reject #rx"unknown result timings"
        "#lang sciencelogo\nelapsed = timings.elapsed\n")
(reject #rx"cannot update protected or unknown name timings"
        "#lang sciencelogo\ntimings.period = 2\n")
(reject #rx"duplicate resource timings"
        "#lang sciencelogo\nresource timings []\nresource timings []\n")
(reject #rx"resource name timings conflicts"
        "#lang sciencelogo\nto timings [output 1]\nresource timings []\n")
(reject #rx"resource name information conflicts"
        "#lang sciencelogo\nresource information []\n")
(reject #rx"duplicate result timings"
        "#lang sciencelogo\nresource timings []\nto value [output 1]\ndo value as timings\n")
(reject #rx"resource belongs directly in a workflow"
        "#lang sciencelogo\nto plan [resource timings [] output true]\n")
(reject #rx"resource needs named fields"
        "#lang sciencelogo\nresource timings [\"file.csv\"]\n")
(reject #rx"unknown result timings"
        "#lang sciencelogo\nresource timings []\nprint timings\n")
(reject #rx"resource write reads an unavailable state location"
        (string-append
         "#lang sciencelogo\nresource timings []\n"
         "stage \"Inspect\" from state [information = []]\n"
         "timings.period = information.absent + 1\n"
         "end stage with state [information = []]\n"))
(reject #rx"resource read list position must exist in state"
        (string-append
         "#lang sciencelogo\nresource timings []\n"
         "stage \"Inspect\" from state [information = [trials = [unknown]]]\n"
         "information.trials.[2] = timings.[2]\n"
         "end stage with state [information = [trials = [unknown]]]\n"))

(with-source
 "#lang sciencelogo\nelapsed = timings.elapsed\nresource timings [url = \"https://example.org/data\"]\nprint elapsed\n"
 (lambda (path)
   (check-equal? (with-output-to-string (lambda () (dynamic-require path #f)))
                 "unknown\n")))

(with-source
 "#lang sciencelogo\nresource timings []\nprint timings.elapsed\n"
 (lambda (path)
   (define model (read-workflow-model path))
   (define activity (first (workflow-model-activities model)))
   (check-true
    (related? 'reads-from activity (first (workflow-model-resources model)) model))
   (check-equal? (activity-model-details activity)
                 '(print (field-ref elapsed (result timings))))))
