#lang racket/base

(require rackunit racket/file racket/list racket/port racket/runtime-path
         "../assessor.rkt" "../workflow-model.rkt" "../private/reader.rkt")

(define-runtime-path pendulum-protocol-example "../examples/interfaces/pendulum-protocol.rkt")

(define (with-sources interface-text workflow-text use)
  (define directory (make-temporary-file "sciencelogo-interfaces-~a" 'directory))
  (define interface (build-path directory "interface.rkt"))
  (define workflow (build-path directory "workflow.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (display-to-file (string-append "#lang sciencelogo\n" interface-text) interface)
      (display-to-file (string-append "#lang sciencelogo\n" workflow-text) workflow)
      (use interface workflow))
    (lambda () (delete-directory/files directory))))

(define (output-of source)
  (with-sources "" source
    (lambda (_interface workflow)
      (with-output-to-string (lambda () (dynamic-require workflow #f))))))

(module+ test
  (define nested-protocol
    (regexp-replace #rx"^#lang sciencelogo\n" (file->string pendulum-protocol-example) ""))
  (with-sources nested-protocol ""
    (lambda (interface _workflow)
      (define model (read-interface-model interface))
      (define entries (interface-model-conditions model))
      (check-equal? (map condition-model-target entries)
                    '(measurement documentation documentation.uncertainty
                                  documentation.notes additional-measurements))
      (check-equal? (map condition-model-kind entries)
                    '(required-entry required-entry required-entry optional-entry optional-entry))
      (check-equal? (condition-model-scope (third entries)) (condition-model-id (second entries)))
      (check-equal? (map relation-model-kind (interface-model-relations model)) '(contains contains))
      (check-true (andmap source-ref? (map condition-model-source entries)))))

  (define (check-provisions interface-text provisions expected-parts expected-checks)
    (with-sources
     interface-text
     (string-append "implements \"interface.rkt\" as protocol [" provisions "]\n")
     (lambda (_interface workflow)
       (define result (assess-file workflow))
       (check-equal? (map finding-part (assessment-findings result)) expected-parts)
       (check-equal? (map condition-check-outcome (assessment-checks result)) expected-checks)
       result)))
  ;; A parent provision asserts its required children, without claiming optional parts.
  (define parent-claim
    (check-provisions nested-protocol
                      "provide measurement by \"timing\" provide documentation by \"record\""
                      '() '(satisfied satisfied satisfied)))
  (check-equal? (condition-check-evidence (second (assessment-checks parent-claim)))
                (condition-check-evidence (third (assessment-checks parent-claim))))
  (void (check-provisions nested-protocol
                          "provide measurement by \"timing\" provide documentation.uncertainty by \"record\""
                          '() '(satisfied satisfied satisfied)))
  (void (check-provisions nested-protocol
                          "provide measurement by \"timing\" provide documentation.notes by \"notes\""
                          '(documentation.uncertainty) '(satisfied satisfied violated)))
  (void (check-provisions nested-protocol "provide measurement by \"timing\""
                          '(documentation) '(satisfied violated)))
  (void (check-provisions nested-protocol
                          "provide measurement by \"timing\" provide documentation by \"record\" provide documentation.uncertainty by \"detail\""
                          '() '(satisfied satisfied satisfied)))

  (define optional-nested
    "interface \"Protocol\" [must [documentation [must [uncertainty] appendix [must [reason] notes]]]]\n")
  (void (check-provisions optional-nested "provide documentation by \"record\""
                          '() '(satisfied satisfied)))
  (void (check-provisions optional-nested
                          "provide documentation by \"record\" provide documentation.appendix.notes by \"notes\""
                          '(documentation.appendix.reason) '(satisfied satisfied violated)))
  (void (check-provisions
         "interface \"Repeated\" [must [observation [must [value]] calibration [must [value]]]]\n"
         "provide observation by \"measurements\" provide calibration.value by \"calibration\""
         '() '(satisfied satisfied satisfied satisfied)))
  (with-sources
   "interface \"Links\" [must [documentation [must [source result] affects source result]]]\n"
   "implements \"interface.rkt\" as protocol [provide documentation.result by \"result\"]\n"
   (lambda (_interface workflow)
     (define findings (assessment-findings (assess-file workflow)))
     (check-equal? (map finding-kind findings) '(missing-part affected-part))
     (check-equal? (finding-chain (second findings)) '(documentation.source documentation.result))))

  ;; Parent blocks are shapes, so they use no assignment or new declaration word.
  (define nested-record
    (string-append
     "interface \"Protocol\" [must [documentation [must [uncertainty unit = \"seconds\"] notes]] "
     "appendix [must [reason] method = \"manual\"]]\n"))
  (check-equal?
   (output-of
    (string-append nested-record
                   "trial = Protocol.[documentation = [uncertainty = [estimate = unknown]]]\n"
                   "print trial.documentation.unit\n"
                   "part = Protocol.documentation.[uncertainty = \"hand timed\"]\n"
                   "print part.unit\n"))
   "seconds\nseconds\n")
  (check-equal?
   (output-of
    (string-append nested-record
                   "trial = Protocol.[documentation = [uncertainty = [estimate = unknown]] appendix = [reason = \"review\"]]\n"
                   "print trial.appendix.method\n"))
   "manual\n")
  (check-exn #rx"missing field documentation.uncertainty"
             (lambda () (output-of (string-append nested-record "trial = Protocol.[]\n"))))
  (with-sources
   nested-record
   (string-append nested-record
                  "trial = [documentation = [uncertainty = [estimate = unknown] unit = \"seconds\"]]\n"
                  "trial implement Protocol\n"
                  "trial implement \"interface.rkt\"\n"
                  "trial.documentation implement Protocol.documentation\n"
                  "trial.appendix = [method = \"manual\"]\n"
                  "trial implement Protocol\n"
                  "trial implement \"interface.rkt\"\n")
   (lambda (_interface workflow)
     (define result (assess-file workflow))
     (check-equal? (map condition-check-outcome (assessment-checks result))
                   '(satisfied satisfied satisfied violated violated))
     (check-equal? (map finding-part (assessment-findings result))
                   '((appendix.reason) (appendix.reason)))))
  (with-sources
   nested-record
   (string-append nested-record
                  "details = [uncertainty = [estimate = unknown] unit = \"seconds\"]\n"
                  "trial = [documentation = details]\n"
                  "trial implement Protocol\n"
                  "missing-details = unknown\n"
                  "trial.documentation = missing-details\n"
                  "trial implement Protocol\n"
                  "trial implement \"interface.rkt\"\n")
   (lambda (_interface workflow)
     (check-equal? (map condition-check-outcome (assessment-checks (assess-file workflow)))
                   '(satisfied violated violated))))

  (check-equal?
   (output-of
    (string-append
     "interface \"Child\" [extends Base]\n"
     "interface \"Base\" [must [documentation [must [unit = \"seconds\"] notes]]]\n"
     "trial = Child.[]\nprint trial.documentation.unit\n"))
   "seconds\n")
  (for ([body (in-list '("must [documentation [must [uncertainty uncertainty]]]"
                         "must [documentation [must [uncertainty]]] documentation.uncertainty"
                         "documentation [version \"1\"]"
                         "documentation [extends Parent]"))])
    (with-sources (string-append "interface \"Invalid\" [" body "]\n") ""
      (lambda (interface _workflow)
        (check-exn exn:fail:read? (lambda () (parse-sciencelogo-file interface))))))

  ;; Requiredness does not depend on line breaks or on explicit value supply.
  (for ([declaration
         (in-list '("interface \"Timing\" [must [duration unit = \"seconds\"] notes]\n"
                    "interface \"Timing\" [\nmust [\nduration\nunit = \"seconds\"\n]\nnotes\n]\n"
                    "interface \"Timing\" [must [duration] unit = \"seconds\" notes]\n"))])
    (check-equal?
     (output-of
      (string-append declaration
                     "trial = Timing.[duration = 2]\nprint trial\n"
                     "other = Timing.[duration = 3 unit = \"minutes\" notes = \"checked\"]\n"
                     "print other.unit\nprint other.notes\n"))
     "[duration = 2 unit = \"seconds\"]\nminutes\nchecked\n")
    (with-sources declaration ""
      (lambda (interface _workflow)
        (define entries (interface-model-conditions (read-interface-model interface)))
        (check-equal? (map condition-model-kind entries)
                      '(required-entry required-entry optional-entry))
        (check-equal? (map condition-model-target entries) '(duration unit notes))
        (check-equal? (condition-model-evidence (second entries)) '(literal "seconds"))
        (check-true (andmap source-ref? (map condition-model-source entries))))))

  (check-equal?
   (output-of "interface \"Optional\" [notes]\nrecord = Optional.[]\nprint record\n")
   "[]\n")
  (check-equal?
   (output-of
    (string-append
     "interface \"Settings\" [must [enabled = false count = 0 value = unknown options = [1 2]]]\n"
     "settings = Settings.[]\nprint settings.enabled\nprint settings.count\n"
     "print settings.value\nprint settings.options\n"))
   "false\n0\nunknown\n[1 2]\n")
  (check-exn
   #rx"missing field duration"
   (lambda ()
     (output-of "interface \"Timing\" [must [duration] notes]\ntrial = Timing.[]\n")))

  ;; The same entries are required in standalone and inline record checks.
  (for ([declaration
         (in-list '("interface \"Timing\" [must [duration unit = \"seconds\"] notes]\n"
                    "interface \"Timing\" [must [duration] unit = \"seconds\" notes]\n"))])
    (with-sources
     declaration
     (string-append
      declaration
      "trial = [duration = 2]\n"
      "trial implement Timing\n"
      "trial implement \"interface.rkt\"\n"
      "trial.unit = \"minutes\"\n"
      "trial implement Timing\n"
      "trial implement \"interface.rkt\"\n")
     (lambda (_interface workflow)
       (define result (assess-file workflow))
       (check-equal? (map condition-check-outcome (assessment-checks result))
                     '(violated violated satisfied satisfied))
       (check-equal? (map finding-part (assessment-findings result)) '((unit) (unit))))))

  ;; Inherited required, defaulted, and optional fields retain their meanings.
  (check-equal?
   (output-of
    (string-append
     "interface \"Combined\" [extends Timing extends Location must [count = 10] notes]\n"
     "interface \"Timing\" [must [duration unit = \"seconds\"] uncertainty]\n"
     "interface \"Location\" [place]\n"
     "trial = Combined.[duration = 2]\nprint trial\n"))
   "[count = 10 duration = 2 unit = \"seconds\"]\n")
  (check-exn
   #rx"conflicting inherited field notes"
   (lambda ()
     (output-of
      (string-append
       "interface \"Combined\" [extends Required extends Optional]\n"
       "interface \"Required\" [must [notes]]\n"
       "interface \"Optional\" [notes]\n"))))

  ;; Dotted fields follow the same presence and default rules.
  (check-equal?
   (output-of
    (string-append
     "interface \"Clock\" [must [clock.time clock.unit = \"seconds\"] clock.notes]\n"
     "trial = Clock.[clock.time = \"12:00\"]\nprint trial.clock\n"))
   "[time = \"12:00\" unit = \"seconds\"]\n")

  ;; Workflow provisions use the same compulsory and optional entries.
  (with-sources
   "interface \"Optional\" [notes]\n"
   "implements \"interface.rkt\" as protocol []\n"
   (lambda (_interface workflow)
     (define result (assess-file workflow))
     (check-equal? (assessment-findings result) '())
     (check-equal? (assessment-checks result) '())))
  (for ([declaration
         (in-list '("interface \"Protocol\" [must [measurement documentation] notes]\n"
                    "interface \"Protocol\" [must [measurement] must [documentation] notes]\n"))])
    (with-sources
     declaration
     (string-append
      "implements \"interface.rkt\" as protocol [provide measurement by \"measurement\"]\n")
     (lambda (_interface workflow)
       (define result (assess-file workflow))
       (check-equal? (map finding-kind (assessment-findings result)) '(missing-part))
       (check-equal? (map finding-part (assessment-findings result)) '(documentation))
       (check-equal? (map condition-check-outcome (assessment-checks result))
                     '(satisfied violated)))))

  (for ([body (in-list '("must []" "must duration" "must [notes] notes"
                         "must [unit = \"seconds\"] unit"
                         "require duration" "must [version \"1\"]"
                         "must [must [duration]]" "must [duration"))])
    (with-sources (string-append "interface \"Invalid\" [" body "]\n") ""
      (lambda (interface _workflow)
        (check-exn exn:fail:read? (lambda () (parse-sciencelogo-file interface)))))))
