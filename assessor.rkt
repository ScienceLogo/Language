#lang racket/base

(require racket/list
         racket/match
         racket/path
         racket/string
         "private/reader.rkt")

(provide assess-file
         render-assessment
         (struct-out assessment)
         (struct-out assessed-interface)
         (struct-out finding))

;; An assessment concerns the declarations in a ScienceLogo method. A provision
;; names an implementation; it does not establish that the implementation works.
(struct finding (kind interface part chain) #:transparent)
(struct assessed-interface (alias name version source) #:transparent)
(struct assessment (title source interfaces findings) #:transparent)

(define (impact-paths edges start)
  (define seen (make-hasheq))
  (hash-set! seen start #t)
  (define (walk part chain)
    (apply append
           (for/list ([next (in-list (hash-ref edges part '()))]
                      #:unless (hash-ref seen next #f))
             (hash-set! seen next #t)
             (define next-chain (append chain (list next)))
             (cons next-chain (walk next next-chain)))))
  (walk start (list start)))

(define (assess-implementation declaration method-path)
  (match-define (list 'implements (list path alias) provisions) declaration)
  (define interface-path
    (simplify-path (build-path (path-only method-path) (string->path path))))
  (if (file-exists? interface-path)
      (assess-existing-interface alias provisions interface-path)
      (values #f (list (finding 'missing-interface-file alias path '())))))

(define (assess-existing-interface alias provisions interface-path)
  (define interface (parse-sciencelogo-file interface-path))
  (unless (and (list? interface) (eq? (car interface) 'interface))
    (error 'assess-file "~a is not a ScienceLogo interface" interface-path))
  (match-define (list 'interface name forms) interface)
  (define version (cadr (findf (lambda (form) (eq? (car form) 'version)) forms)))
  (define required
    (for/list ([form (in-list forms)] #:when (eq? (car form) 'require))
      (cadr form)))
  (define required-set (make-hasheq))
  (for ([part (in-list required)]) (hash-set! required-set part #t))
  (define edges (make-hasheq))
  (for ([form (in-list forms)] #:when (eq? (car form) 'affects))
    (match-define (list 'affects from to) form)
    (hash-update! edges from (lambda (targets) (append targets (list to))) '()))
  (define provided (make-hasheq))
  (define provision-findings
    (append*
     (for/list ([form (in-list provisions)])
       (match-define (list 'provide part _locator) form)
       (define issue
         (cond
           [(not (hash-has-key? required-set part))
            (finding 'unknown-part alias part '())]
           [(hash-has-key? provided part)
            (finding 'duplicate-part alias part '())]
           [else #f]))
       (hash-set! provided part #t)
       (if issue (list issue) '()))))
  (define missing
    (filter (lambda (part) (not (hash-has-key? provided part))) required))
  (define missing-findings
    (for/list ([part (in-list missing)])
      (finding 'missing-part alias part (list part))))
  (define impact-findings
    (append*
     (for/list ([part (in-list missing)])
       (for/list ([chain (in-list (impact-paths edges part))])
         (finding 'affected-part alias (last chain) chain)))))
  (values (assessed-interface alias name version interface-path)
          (append provision-findings missing-findings impact-findings)))

(define (assess-file path)
  (define source (path->complete-path path))
  (define method (parse-sciencelogo-file source))
  (unless (and (list? method) (eq? (car method) 'investigate))
    (error 'assess-file "~a is not a ScienceLogo investigation" source))
  (match-define (list 'investigate title forms) method)
  (define interfaces '())
  (define findings '())
  (define aliases (make-hasheq))
  (for ([form (in-list forms)] #:when (eq? (car form) 'implements))
    (match-define (list 'implements (list _ alias) _) form)
    (if (hash-has-key? aliases alias)
        (set! findings
              (append findings (list (finding 'duplicate-interface-alias alias alias '()))))
        (let-values ([(interface issues) (assess-implementation form source)])
          (hash-set! aliases alias #t)
          (when interface (set! interfaces (append interfaces (list interface))))
          (set! findings (append findings issues)))))
  (assessment title source interfaces findings))

(define (render-assessment result [out (current-output-port)])
  (fprintf out "ScienceLogo assessment: ~a\n" (assessment-title result))
  (for ([interface (in-list (assessment-interfaces result))])
    (fprintf out "Interface ~a: ~a, version ~a (~a)\n"
             (assessed-interface-alias interface)
             (assessed-interface-name interface)
             (assessed-interface-version interface)
             (assessed-interface-source interface)))
  (if (null? (assessment-findings result))
      (displayln "No structural issues found." out)
      (for ([issue (in-list (assessment-findings result))])
        (case (finding-kind issue)
          [(missing-part)
           (fprintf out "Missing ~a required by ~a.\n"
                    (finding-part issue) (finding-interface issue))]
          [(affected-part)
           (fprintf out "Affected ~a through ~a.\n"
                    (finding-part issue)
                    (string-join (map symbol->string (finding-chain issue)) " -> "))]
          [(unknown-part)
           (fprintf out "Unknown part ~a in ~a.\n"
                    (finding-part issue) (finding-interface issue))]
          [(duplicate-part)
           (fprintf out "Duplicate provision ~a in ~a.\n"
                    (finding-part issue) (finding-interface issue))]
          [(missing-interface-file)
           (fprintf out "Missing interface file ~a for ~a.\n"
                    (finding-part issue) (finding-interface issue))]
          [(duplicate-interface-alias)
           (fprintf out "Duplicate interface alias ~a.\n"
                    (finding-interface issue))]))))

(module+ main
  (require racket/cmdline)
  (define method-path
    (command-line #:program "sciencelogo-assessor" #:args (method) method))
  (define result (assess-file method-path))
  (render-assessment result)
  (unless (null? (assessment-findings result)) (exit 1)))
