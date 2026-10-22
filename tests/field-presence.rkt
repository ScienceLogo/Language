#lang racket/base

(require rackunit racket/file racket/list racket/port racket/runtime-path
         "../assessor.rkt" "../workflow-model.rkt"
         "../private/constant-values.rkt" "../private/record-interfaces.rkt")

(define-runtime-path example "../examples/field-presence.rkt")
(define (with-source body use)
  (define file (make-temporary-file "sciencelogo-presence-~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\nworkflow \"Field presence\"\n" body)
                                file #:exists 'truncate))
    (lambda () (use file))
    (lambda () (delete-file file))))
(define (run body)
  (with-source body (lambda (file) (with-output-to-string (lambda () (dynamic-require file #f))))))
(define (outcomes body)
  (with-source body (lambda (file) (map condition-check-outcome (assessment-checks (assess-file file))))))

(module+ test
  ;; Presence checks keys, including fields with unknown or false values.
  (for ([expression (in-list '("notes in [notes = \"recorded\"]"
                              "notes in [notes = unknown]" "notes in [notes = false]"
                              "count in [count = 3]" "notes in ([notes = unknown] u [])"))])
    (check-equal? (run (string-append "print " expression "\n")) "true\n"))
  (for ([expression (in-list '("notes in [period = 2]"
                              "notes in [details = [notes = \"nested\"]]"
                              "count in [period = 2]"))])
    (check-equal? (run (string-append "print " expression "\n")) "false\n"))
  (check-equal? (run "trial = [details = [notes = unknown]]\nprint notes in trial.details\nprint not (period in trial.details)\nprint notes in unknown\n")
                "true\ntrue\nunknown\n")
  ;; A record uses the bare word as a key, even when that word has a value.
  ;; A list still uses its value, and a receiver can change kind.
  (check-equal? (run "notes = \"manual\"\ntrial = [notes = unknown]\nprint notes in trial\ntrial = [\"manual\" \"video\"]\nprint notes in trial\ntrial = [method = \"manual\"]\nprint notes in trial\n")
                "true\ntrue\nfalse\n")
  (check-equal? (run "to present :trial [output notes in :trial]\ndo present [notes = unknown] as found\nprint found\ndo present [period = 2] as absent\nprint absent\n")
                "true\nfalse\n")
  (check-equal? (run "trial = [notes = unknown]\npresent = notes in trial\nif present [print \"present\"] else if period in trial [print \"period\"] else [print \"neither\"]\nfor each entry in [[notes = unknown] [period = 2]] [print notes in entry]\n")
                "present\ntrue\nfalse\n")
  (check-exn #rx"unquoted field name" (lambda () (run "print \"notes\" in [notes = 2]\n")))
  (check-exn #rx"unquoted field name" (lambda () (run "print 2 in [notes = 2]\n")))
  (check-exn #rx"list or record" (lambda () (run "print notes in 2\n")))
  (check-exn #rx"unknown result notes" (lambda () (run "print notes in [2]\n")))
  ;; Ordinary name checks remain strict outside this contextual field label.
  (check-exn #rx"unknown result notes" (lambda () (run "print notes == 2\n")))

  ;; Static evaluation needs only the record's keys, not its field values.
  (define presence '(compare in ((result notes) (result trial))))
  (check-equal? (constant-value presence (lambda (_) (hasheq 'notes no-constant))) #t)
  (check-equal? (constant-value presence (lambda (_) (hasheq 'period no-constant))) #f)
  (check-eq? (constant-value presence) no-constant)
  (check-equal? (constant-value presence (lambda (_) 'unknown)) 'unknown)

  (define requirement "interface Noted [must [notes in details]]\n")
  (for ([details (in-list '("[notes = unknown]" "[notes = false]" "[period = 2]"))]
        [expected (in-list '(satisfied satisfied violated))])
    (check-equal? (outcomes (string-append requirement "trial = [details = " details "]\ntrial implement Noted\n"))
                  (list expected)))
  (check-equal? (run (string-append requirement "trial = Noted.[details = [notes = unknown]]\nprint notes in trial.details\n"))
                "true\n")
  (check-exn #rx"does not satisfy value requirement"
             (lambda () (run (string-append requirement "trial = Noted.[details = [period = 2]]\n"))))
  (check-equal? (outcomes (string-append requirement "trial = [details = [\"manual\"] notes = \"manual\"]\ntrial implement Noted\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append requirement "trial = [details = [\"manual\"]]\ntrial implement Noted\n"))
                '(violated))
  (check-equal? (outcomes "interface Noted [must [details = unknown notes in details]]\ntrial = [details = unknown]\ntrial implement Noted\n")
                '(undetermined))
  (check-equal? (outcomes (string-append requirement "to describe [output [notes = unknown]]\ndo describe as details\ntrial = [details = details]\ntrial implement Noted\n"))
                '(undetermined))

  ;; An optional key is not made compulsory by testing for its presence.
  (define conditional
    "interface Trial [details [notes] if notes in details [must [reviewer]] else [must [reason]]]\n")
  (check-equal? (run (string-append conditional "trial = Trial.[details = [period = 2] reason = \"no notes\"]\nprint trial.reason\n"))
                "no notes\n")
  (check-equal? (outcomes (string-append conditional "trial = [details = [notes = unknown] reviewer = \"human\"]\ntrial implement Trial\n"))
                '(satisfied))
  (check-equal? (outcomes (string-append conditional "trial = [details = [notes = unknown]]\ntrial implement Trial\n"))
                '(violated))
  (check-equal? (outcomes "interface Series [for each entry in trials [must [notes in entry]]]\nseries = [trials = [[notes = unknown] [notes = false]]]\nseries implement Series\n")
                '(satisfied))
  (check-equal? (outcomes "interface Series [for each entry in trials [must [notes in entry]]]\nseries = [trials = [[notes = unknown] [period = 2]]]\nseries implement Series\n")
                '(violated))

  ;; The model preserves the expression and makes value dependencies
  ;; conditional on a list receiver, rather than inventing a field variable.
  (with-source "notes = \"manual\"\ntrial = [notes = unknown]\nif notes in trial [print \"present\"]\n"
    (lambda (file)
      (define model (read-workflow-model file))
      (define branch (findf (lambda (activity) (eq? (activity-model-kind activity) 'branch))
                            (workflow-model-activities model)))
      (check-equal? (activity-model-control branch) presence)
      (define note-item (findf (lambda (item) (eq? (item-model-name item) 'notes))
                              (workflow-model-items model)))
      (define use
        (findf (lambda (relation)
                 (and (eq? (relation-model-kind relation) 'uses)
                      (equal? (relation-model-from relation) (activity-model-id branch))
                      (equal? (relation-model-to relation) (item-model-id note-item))))
               (workflow-model-relations model)))
      (check-true (guarded-relation-model? use))
      (check-equal? (guarded-relation-model-guard use) '(kind-test list ((result trial))))))
  (with-source (string-append requirement "stage Record\nRecord implement Noted\n")
    (lambda (file)
      (define model (read-workflow-model file))
      (define interface (mapping-model-interface (first (workflow-model-mappings model))))
      (define selector
        (findf (lambda (condition) (eq? (condition-model-target condition) 'notes))
               (interface-model-conditions interface)))
      (check-equal? (condition-model-guard selector) '(kind-test list ((result details))))))
  (with-source "trial = [notes = unknown]\nif notes in trial [print \"present\"]\n"
    (lambda (file) (check-not-exn (lambda () (read-workflow-model file)))))
  (with-source "performer researcher []\nto keep :value [output :value]\nstage Inspect by researcher from state [information = [trial = [notes = unknown]]]\nif notes in information.trial [do keep with [value at information.trial] into information.trial]\nend stage with state [information = [trial = [notes = unknown]]]\n"
    (lambda (file) (check-not-exn (lambda () (read-workflow-model file)))))

  (check-equal? (with-output-to-string (lambda () (dynamic-require example #f)))
                "period is present\nnotes is absent\nmethod is allowed\n")
  (check-equal? (assessment-findings (assess-file example)) '()))
