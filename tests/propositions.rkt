#lang racket/base

(require rackunit racket/file racket/list racket/port
         "../assessor.rkt" "../workflow-model.rkt")

(define (with-source content use)
  (define path (make-temporary-file "sciencelogo-proposition-~a.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file path
        (lambda (out) (display content out))
        #:exists 'truncate)
      (use path))
    (lambda () (delete-file path))))

(define example
  (string-append
   "#lang sciencelogo\n"
   "workflow \"Review a pendulum claim\"\n"
   "hypothesis shorter-swing [text = \"A shorter swing has a shorter period\"]\n"
   "assumption hand-timing [text = \"Hand timing is comparable\"]\n"
   "conclusion regular-period [text = \"The period was nearly constant\"]\n"
   "stage Review\n"
   "hypotheses.shorter-swing += conclusion not-supported [text = \"Measurements did not support it\"]\n"
   "hypotheses.shorter-swing.conclusions.not-supported.text = \"Revised finding\"\n"
   "print conclusions.regular-period.text\n"
   "print hypotheses.shorter-swing.conclusions.not-supported.text\n"
   "print assumptions.hand-timing.text\n"))

(module+ test
  (with-source
   example
   (lambda (path)
     (check-equal?
      (with-output-to-string (lambda () (dynamic-require path #f)))
      "The period was nearly constant\nRevised finding\nHand timing is comparable\n")
     (define method (read-workflow-model path))
     (check-equal? (map proposition-model-name (workflow-model-propositions method))
                   '(shorter-swing hand-timing regular-period))
     (check-equal? (map proposition-model-type (workflow-model-propositions method))
                   '(hypothesis assumption conclusion))
     (check-equal? (map stage-model-name (workflow-model-stages method))
                   '("Review"))
     (check-true
      (for/or ([relation (in-list (workflow-model-relations method))])
        (and (eq? (relation-model-kind relation) 'uses)
             (equal? (relation-model-to relation)
                     (proposition-model-id
                      (first (workflow-model-propositions method)))))))
     (check-false
      (for/or ([finding (in-list (assessment-findings (assess-file path)))])
        (eq? (finding-kind finding) 'invalid-relation)))))
  (with-source
   (string-append
    "#lang sciencelogo\n"
    "hypothesis shorter-swing [text = \"Shorter\" conclusions = [first = [text = \"Initial answer\"]]]\n"
    "hypotheses.shorter-swing.conclusions.first.text = \"Revised answer\"\n"
    "conclusions += conclusion independent [text = \"Another finding\"]\n"
    "print hypotheses.shorter-swing.conclusions.first.text\n"
    "print conclusions.independent.text\n")
   (lambda (path)
     (check-equal?
      (with-output-to-string (lambda () (dynamic-require path #f)))
      "Revised answer\nAnother finding\n")))
  (with-source
   (string-append
    "#lang sciencelogo\n"
    "hypothesis shorter-swing [text = \"Shorter\"]\n"
    "stage Compare from state [information = [claim = hypotheses.shorter-swing]]\n"
    "end stage with state [information = [claim = hypotheses.shorter-swing]]\n")
   (lambda (path)
     (check-equal? (length (workflow-model-stages (read-workflow-model path))) 1)))
  (with-source
   (string-append
    "#lang sciencelogo\n"
    "hypothesis shorter-swing [text = \"Shorter\"]\n"
    "performer researcher []\n"
    "to revise :claim [\n"
    "  revised = :claim\n"
    "  revised += conclusion not-supported [text = \"No shortening detected\"]\n"
    "  output revised\n"
    "]\n"
    "stage Conclude by researcher from state [information = [claim = hypotheses.shorter-swing]]\n"
    "do revise with [claim at information.claim] into information.claim\n"
    "end stage with state [information = [claim = unknown]]\n")
   (lambda (path)
     (check-equal? (length (workflow-model-stages (read-workflow-model path))) 1)))
  (define (reject-read pattern content)
    (with-source content
      (lambda (path)
        (check-exn pattern (lambda () (read-workflow-model path))))))
  (define (reject-run pattern content)
    (with-source content
      (lambda (path)
        (check-exn pattern (lambda () (dynamic-require path #f))))))
  (reject-read #rx"proposition conclusions needs named entries"
               "#lang sciencelogo\nhypothesis short [text = \"x\" conclusions = [\"y\"]]\n")
  (reject-read #rx"proposition fields must be"
               "#lang sciencelogo\nhypothesis short [text = \"x\" answers = [1]]\n")
  (reject-read #rx"duplicate hypothesis short"
               "#lang sciencelogo\nhypothesis short [text = \"x\"]\nhypothesis short [text = \"y\"]\n")
  (reject-run #rx"duplicate conclusion answer"
              (string-append
               "#lang sciencelogo\n"
               "hypothesis short [text = \"x\"]\n"
               "hypotheses.short += conclusion answer [text = \"first\"]\n"
               "hypotheses.short += conclusion answer [text = \"second\"]\n"))
  (reject-read #rx"duplicate conclusion answer at hypotheses.short"
               (string-append
                "#lang sciencelogo\n"
                "hypothesis short [text = \"x\"]\n"
                "hypotheses.short += conclusion answer [text = \"first\"]\n"
                "hypotheses.short += conclusion answer [text = \"second\"]\n"))
  (reject-run #rx"cannot contain itself"
              (string-append
               "#lang sciencelogo\n"
               "hypothesis short [text = \"x\"]\n"
               "hypotheses.short += hypothesis short [text = \"y\"]\n"))
  (reject-run #rx"duplicate conclusion answer"
              (string-append
               "#lang sciencelogo\n"
               "hypothesis short [text = \"x\" conclusions = [answer = [text = \"first\"]]]\n"
               "hypotheses.short += conclusion answer [text = \"second\"]\n"))
  (reject-run #rx"missing proposition answer"
              (string-append
               "#lang sciencelogo\n"
               "hypothesis short [text = \"x\"]\n"
               "hypotheses.short.conclusions.answer.text = \"cannot create with =\"\n"))
  (reject-run #rx"missing proposition answer"
              (string-append
               "#lang sciencelogo\n"
               "hypothesis short [text = \"x\"]\n"
               "hypotheses.short.conclusions = [answer = [text = \"cannot create with =\"]]\n"))
  (with-source
   (string-append
    "#lang sciencelogo\n"
    "hypothesis common [text = \"Hypothesis\"]\n"
    "assumption common [text = \"Assumption\"]\n"
    "hypotheses.common += conclusion answer [text = \"One answer\"]\n"
    "assumptions.common += conclusion answer [text = \"Another answer\"]\n"
    "print hypotheses.common.conclusions.answer.text\n"
    "print assumptions.common.conclusions.answer.text\n")
   (lambda (path)
     (check-equal?
      (with-output-to-string (lambda () (dynamic-require path #f)))
      "One answer\nAnother answer\n")))
  (reject-run #rx"wrong proposition type"
              "#lang sciencelogo\nconclusions += hypothesis wrong [text = \"x\"]\n")
  (with-source
   (string-append
    "#lang sciencelogo\n"
    "values = [1]\n"
    "values += [2 3]\n"
    "print values.[2].[1]\n")
   (lambda (path)
     (check-equal?
      (with-output-to-string (lambda () (dynamic-require path #f)))
      "2\n")))
  (with-source
   (string-append
    "#lang sciencelogo\n"
    "review = [conclusions = [first = \"one\"]]\n"
    "review.conclusions += [second = \"two\"]\n"
    "print review.conclusions.second\n")
   (lambda (path)
     (check-equal?
      (with-output-to-string (lambda () (dynamic-require path #f)))
      "two\n"))))
