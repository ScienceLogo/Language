#lang racket/base

(require racket/list
         racket/path
         racket/string
         "workflow-model.rkt")

(provide assess-file
         assess-workflow
         render-assessment
         (struct-out assessment)
         (struct-out assessed-interface)
         (struct-out finding)
         (struct-out condition-check))

;; An assessment concerns the declarations in a ScienceLogo method. A provision
;; names an implementation; it does not establish that the implementation works.
(struct finding (kind interface part chain condition target outcome evidence)
  #:transparent)
(struct condition-check (condition target outcome evidence gap) #:transparent)
(struct assessed-interface (alias name version source id revision) #:transparent)
(struct assessment (title source interfaces findings checks method) #:transparent)

(define (stage-order-target? target)
  (and (list? target)
       (>= (length target) 2)
       (andmap (lambda (name) (and (string? name) (not (string=? name ""))))
               target)
       (= (length target) (length (remove-duplicates target)))))

(define (valid-method-condition? condition method type-of)
  (and (equal? (condition-model-scope condition) (workflow-model-id method))
       (eq? (condition-model-checkpoint condition) 'method)
       (case (condition-model-kind condition)
         [(reachable-call)
          (and (eq? (type-of (condition-model-target condition)) 'procedure)
               (eq? (condition-model-evidence condition) 'reachable-call))]
         [(stage-order)
          (and (stage-order-target? (condition-model-target condition))
               (eq? (condition-model-evidence condition) 'stage-headers))]
         [else #f])))

(define (assess-model-structure method)
  (define elements (make-hash))
  (define issues '())
  (define (register id kind value)
    (when (hash-has-key? elements id)
      (set! issues
            (cons (finding 'duplicate-model-id #f id '()
                           'sciencelogo:unique-element-id id 'violated '())
                  issues)))
    (hash-set! elements id (cons kind value)))
  (register (workflow-model-id method) 'workflow method)
  (for ([stage (in-list (workflow-model-stages method))])
    (register (stage-model-id stage) 'stage stage))
  (for ([procedure (in-list (workflow-model-procedures method))])
    (register (procedure-model-id procedure) 'procedure procedure))
  (for ([activity (in-list (workflow-model-activities method))])
    (register (activity-model-id activity) 'activity activity))
  (for ([item (in-list (workflow-model-items method))])
    (register (item-model-id item) 'item item))
  (for ([import (in-list (workflow-model-imports method))])
    (register (import-model-id import) 'import import))
  (for ([implementation (in-list (workflow-model-implementations method))])
    (register (implementation-model-id implementation)
              'implementation implementation)
    (for ([provision (in-list (implementation-model-provisions implementation))])
      (register (provision-model-id provision) 'provision provision)))
  (for ([condition (in-list (workflow-model-conditions method))])
    (register (condition-model-id condition) 'condition condition))
  (define (type-of id)
    (define entry (hash-ref elements id #f))
    (and entry (car entry)))
  (for ([condition (in-list (workflow-model-conditions method))])
    (unless (valid-method-condition? condition method type-of)
      (set! issues
            (cons (finding 'invalid-condition #f (condition-model-id condition)
                           '() 'sciencelogo:well-formed-condition
                           (condition-model-target condition) 'violated
                           (list (condition-model-source condition)))
                  issues))))
  (define (activity-kind id)
    (define entry (hash-ref elements id #f))
    (and entry (eq? (car entry) 'activity)
         (activity-model-kind (cdr entry))))
  (define (parent-of id)
    (define entry (hash-ref elements id #f))
    (and entry
         (case (car entry)
           [(stage) (stage-model-parent (cdr entry))]
           [(activity) (activity-model-parent (cdr entry))]
           [(item) (item-model-scope (cdr entry))]
           [else #f])))
  (define (execution-parent activity-id)
    (define parent (parent-of activity-id))
    (if (eq? (type-of parent) 'stage)
        (parent-of parent)
        parent))
  (define (same-parent? from to)
    (equal? (execution-parent from) (execution-parent to)))
  (define containment-counts (make-hash))
  (for ([relation (in-list (workflow-model-relations method))])
    (define kind (relation-model-kind relation))
    (define from (relation-model-from relation))
    (define to (relation-model-to relation))
    (define from-type (type-of from))
    (define to-type (type-of to))
    (when (eq? kind 'contains)
      (hash-update! containment-counts to add1 0))
    (define valid?
      (case kind
        [(contains)
         (and (or (memq from-type '(workflow procedure stage))
                  (eq? (activity-kind from) 'sequence))
              (memq to-type '(stage activity item))
              (equal? from (parent-of to)))]
        [(defines) (and (eq? from-type 'workflow) (eq? to-type 'procedure))]
        [(imports)
         (and (eq? from-type 'workflow) (memq to-type '(import procedure)))]
        [(claims-implementation)
         (and (eq? from-type 'workflow) (eq? to-type 'implementation))]
        [(invokes)
         (and (eq? (activity-kind from) 'call) (eq? to-type 'procedure))]
        [(uses)
         (and (eq? from-type 'activity) (eq? to-type 'item))]
        [(produces)
         (and (eq? (activity-kind from) 'call) (eq? to-type 'item)
              (equal? (item-model-producer (cdr (hash-ref elements to))) from))]
        [(depends-on precedes)
         (and (eq? from-type 'activity) (eq? to-type 'activity))]
        [else #f]))
    (unless valid?
      (set! issues
            (cons (finding 'invalid-relation #f kind '()
                           'sciencelogo:well-formed-relation to 'violated
                           (list (relation-model-source relation)))
                  issues)))
    (when (and valid? (eq? kind 'precedes) (not (same-parent? from to)))
      (set! issues
            (cons (finding 'invalid-order-scope #f kind '()
                           'sciencelogo:order-scope to 'violated
                           (list (relation-model-source relation)))
                  issues))))
  (for ([element (in-list (append (workflow-model-stages method)
                                  (workflow-model-activities method)
                                  (workflow-model-items method)))])
    (define id
      (cond [(stage-model? element) (stage-model-id element)]
            [(activity-model? element) (activity-model-id element)]
            [else (item-model-id element)]))
    (define source
      (cond [(stage-model? element) (stage-model-source element)]
            [(activity-model? element) (activity-model-source element)]
            [else (item-model-source element)]))
    (define count (hash-ref containment-counts id 0))
    (unless (= count 1)
      (set! issues
            (cons (finding (if (zero? count)
                               'missing-containment
                               'duplicate-containment)
                           #f id '() 'sciencelogo:one-parent id 'violated
                           (list source))
                  issues))))
  (reverse issues))

(define (assess-required-calls method)
  ;; Only calls reachable from the investigation body count. A procedure that is
  ;; merely defined, or called only by an unused procedure, does not satisfy must do.
  (define activities
    (for/hash ([activity (in-list (workflow-model-activities method))])
      (values (activity-model-id activity) activity)))
  (define stages
    (for/hash ([stage (in-list (workflow-model-stages method))])
      (values (stage-model-id stage) stage)))
  (define procedures
    (for/hash ([procedure (in-list (workflow-model-procedures method))])
      (values (procedure-model-id procedure) procedure)))
  (define links (make-hash))
  (for ([relation (in-list (workflow-model-relations method))]
        #:when
        (case (relation-model-kind relation)
          [(contains)
           (define activity (hash-ref activities (relation-model-to relation) #f))
           (define stage (hash-ref stages (relation-model-to relation) #f))
           (or (and activity
                    (equal? (activity-model-parent activity)
                            (relation-model-from relation)))
               (and stage
                    (equal? (stage-model-parent stage)
                            (relation-model-from relation))))]
          [(invokes)
           (define activity (hash-ref activities (relation-model-from relation) #f))
           (and activity (eq? (activity-model-kind activity) 'call)
                (hash-has-key? procedures (relation-model-to relation)))]
          [else #f]))
    (hash-update! links (relation-model-from relation)
                  (lambda (targets) (cons (relation-model-to relation) targets)) '()))
  (define reachable (make-hash))
  (define (visit id)
    (unless (hash-has-key? reachable id)
      (hash-set! reachable id #t)
      (for ([target (in-list (hash-ref links id '()))]) (visit target))))
  (visit (workflow-model-id method))
  (define names
    (for/hash ([id (in-hash-keys procedures)])
      (values id (procedure-model-name (hash-ref procedures id)))))
  (define call-sites (make-hash))
  (for ([relation (in-list (workflow-model-relations method))]
        #:when (and (eq? (relation-model-kind relation) 'invokes)
                    (hash-has-key? reachable (relation-model-from relation))
                    (let ([activity
                           (hash-ref activities (relation-model-from relation) #f)])
                      (and activity (eq? (activity-model-kind activity) 'call)))
                    (hash-has-key? procedures (relation-model-to relation))))
    (hash-update! call-sites (relation-model-to relation)
                  (lambda (calls) (cons (relation-model-from relation) calls)) '()))
  (define checks '())
  (define findings '())
  (for ([condition (in-list (workflow-model-conditions method))]
        #:when (and (eq? (condition-model-kind condition) 'reachable-call)
                    (hash-has-key? procedures (condition-model-target condition))
                    (equal? (condition-model-scope condition)
                            (workflow-model-id method))
                    (eq? (condition-model-checkpoint condition) 'method)
                    (eq? (condition-model-evidence condition) 'reachable-call)))
    (define target (condition-model-target condition))
    (define calls (reverse (hash-ref call-sites target '())))
    (define satisfied? (pair? calls))
    (set! checks
          (cons (condition-check (condition-model-id condition) target
                                 (if satisfied? 'satisfied 'violated)
                                 calls (if satisfied? #f 'missing-reachable-call))
                checks))
    (unless satisfied?
      (set! findings
            (cons (finding 'missing-required-call #f (hash-ref names target target)
                           '() (condition-model-id condition) target
                           'violated (list (condition-model-source condition)))
                  findings))))
  (values (reverse checks) (reverse findings)))

(define (assess-required-stage-order method)
  ;; This condition concerns top-level headers in the written method, in source order.
  (define stages
    (filter (lambda (stage)
              (equal? (stage-model-parent stage) (workflow-model-id method)))
            (workflow-model-stages method)))
  (define checks '())
  (define findings '())
  (for ([condition (in-list (workflow-model-conditions method))]
        #:when (and (eq? (condition-model-kind condition) 'stage-order)
                    (stage-order-target? (condition-model-target condition))
                    (equal? (condition-model-scope condition)
                            (workflow-model-id method))
                    (eq? (condition-model-checkpoint condition) 'method)
                    (eq? (condition-model-evidence condition) 'stage-headers)))
    (define names (condition-model-target condition))
    (define matches
      (for/list ([name (in-list names)])
        (for/list ([stage (in-list stages)] [index (in-naturals)]
                   #:when (equal? (stage-model-name stage) name))
          (cons index stage))))
    (define missing
      (for/first ([name (in-list names)] [found (in-list matches)]
                  #:when (null? found))
        name))
    (define ambiguous
      (for/first ([name (in-list names)] [found (in-list matches)]
                  #:when (> (length found) 1))
        name))
    (define ordered?
      (and (not missing) (not ambiguous)
           (for/and ([left (in-list matches)] [right (in-list (cdr matches))])
             (< (car (car left)) (car (car right))))))
    (define gap
      (cond [missing 'missing-stage]
            [ambiguous 'ambiguous-stage]
            [(not ordered?) 'stage-order]
            [else #f]))
    (define evidence
      (for/list ([stage (in-list stages)]
                 #:when (member (stage-model-name stage) names))
        (stage-model-id stage)))
    (set! checks
          (cons (condition-check (condition-model-id condition) names
                                 (if gap 'violated 'satisfied) evidence gap)
                checks))
    (when gap
      (set! findings
            (cons (finding
                   (case gap
                     [(missing-stage) 'missing-required-stage]
                     [(ambiguous-stage) 'ambiguous-required-stage]
                     [else 'required-stage-order])
                   #f (or missing ambiguous names) '()
                   (condition-model-id condition) names 'violated
                   (list (condition-model-source condition)))
                  findings))))
  (values (reverse checks) (reverse findings)))

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
  (define path (implementation-model-path declaration))
  (define alias (implementation-model-alias declaration))
  (define interface-path
    (simplify-path (build-path (path-only method-path) (string->path path))))
  (if (file-exists? interface-path)
      (assess-existing-interface declaration interface-path)
      (values #f
              (list (finding 'missing-interface-file alias path '()
                             'sciencelogo:interface-resolves
                             (implementation-model-id declaration)
                             'violated
                             (list (implementation-model-source declaration))))
              '())))

(define (assess-existing-interface declaration interface-path)
  (define alias (implementation-model-alias declaration))
  (define provisions (implementation-model-provisions declaration))
  (define interface (read-interface-model interface-path))
  (define conditions (interface-model-conditions interface))
  (define condition-by-part
    (for/hasheq ([condition (in-list conditions)])
      (values (condition-model-target condition) condition)))
  (define part-by-id
    (for/hash ([condition (in-list conditions)])
      (values (condition-model-id condition) (condition-model-target condition))))
  (define edges (make-hasheq))
  (define edge-sources (make-hash))
  (for ([relation (in-list (interface-model-relations interface))])
    (define from (hash-ref part-by-id (relation-model-from relation)))
    (define to (hash-ref part-by-id (relation-model-to relation)))
    (hash-update! edges from (lambda (targets) (append targets (list to))) '())
    (hash-set! edge-sources (cons from to) (relation-model-source relation)))
  (define provided (make-hasheq))
  (define provision-findings
    (append*
     (for/list ([provision (in-list provisions)])
       (define part (provision-model-part provision))
       (define issue
         (cond
           [(not (hash-has-key? condition-by-part part))
            (finding 'unknown-part alias part '()
                     'sciencelogo:known-part (provision-model-id provision)
                     'violated (list (provision-model-source provision)))]
           [(hash-has-key? provided part)
            (finding 'duplicate-part alias part '()
                     'sciencelogo:unique-provision (provision-model-id provision)
                     'violated (list (provision-model-source provision)))]
           [else #f]))
       (hash-set! provided part provision)
       (if issue (list issue) '()))))
  (define missing
    (filter (lambda (part) (not (hash-has-key? provided part)))
            (map condition-model-target conditions)))
  (define checks
    (for/list ([condition (in-list conditions)])
      (define part (condition-model-target condition))
      (define provision (hash-ref provided part #f))
      (condition-check (condition-model-id condition)
                       (format "~a/part:~a" (implementation-model-id declaration) part)
                       (if provision 'satisfied 'violated)
                       (if provision (list (provision-model-id provision)) '())
                       (if provision #f 'missing-provision))))
  (define missing-findings
    (for/list ([part (in-list missing)])
      (finding 'missing-part alias part (list part)
               (condition-model-id (hash-ref condition-by-part part))
               (format "~a/part:~a" (implementation-model-id declaration) part)
               'violated '())))
  (define impact-findings
    (append*
     (for/list ([part (in-list missing)])
       (for/list ([chain (in-list (impact-paths edges part))])
         (finding 'affected-part alias (last chain) chain
                  (condition-model-id (hash-ref condition-by-part part))
                  (condition-model-id (hash-ref condition-by-part (last chain)))
                  'undetermined
                  (for/list ([from (in-list chain)]
                             [to (in-list (cdr chain))])
                    (hash-ref edge-sources (cons from to))))))))
  (values (assessed-interface alias (interface-model-name interface)
                              (interface-model-version interface)
                              interface-path (interface-model-id interface)
                              (interface-model-revision interface))
          (append provision-findings missing-findings impact-findings)
          checks))

(define (assess-workflow method)
  (unless (workflow-model? method)
    (raise-argument-error 'assess-workflow "workflow-model?" method))
  (define interfaces '())
  (define findings (assess-model-structure method))
  (define-values (checks required-call-findings)
    (assess-required-calls method))
  (set! findings (append findings required-call-findings))
  (define-values (stage-checks stage-findings)
    (assess-required-stage-order method))
  (set! checks (append checks stage-checks))
  (set! findings (append findings stage-findings))
  (define aliases (make-hasheq))
  (for ([form (in-list (workflow-model-implementations method))])
    (define alias (implementation-model-alias form))
    (if (hash-has-key? aliases alias)
        (set! findings
              (append findings
                      (list (finding 'duplicate-interface-alias alias alias '()
                                     'sciencelogo:unique-interface-alias
                                     (implementation-model-id form)
                                     'violated
                                     (list (implementation-model-source form))))))
        (let-values ([(interface issues results)
                      (assess-implementation form (workflow-model-source method))])
          (hash-set! aliases alias #t)
          (when interface (set! interfaces (append interfaces (list interface))))
          (set! findings (append findings issues))
          (set! checks (append checks results)))))
  (assessment (or (workflow-model-title method) (workflow-model-source method))
              (workflow-model-source method)
              interfaces findings checks method))

(define (assess-file path)
  (assess-workflow (read-workflow-model path)))

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
                    (finding-interface issue))]
          [(duplicate-model-id)
           (fprintf out "Duplicate method element identity ~a.\n"
                    (finding-part issue))]
          [(invalid-relation)
           (fprintf out "Invalid ~a relation to ~a.\n"
                    (finding-part issue) (finding-target issue))]
          [(invalid-order-scope)
           (fprintf out "Order relation crosses activity scopes at ~a.\n"
                    (finding-target issue))]
          [(missing-containment)
           (fprintf out "Missing containment relation for ~a.\n"
                    (finding-target issue))]
          [(duplicate-containment)
           (fprintf out "Multiple containment relations for ~a.\n"
                    (finding-target issue))]
          [(missing-required-call)
           (fprintf out "Required call to ~a is absent from the investigation.\n"
                    (finding-part issue))]
          [(missing-required-stage)
           (fprintf out "Required stage ~s is absent from the workflow.\n"
                    (finding-part issue))]
          [(ambiguous-required-stage)
           (fprintf out "Required stage ~s has more than one top-level header.\n"
                    (finding-part issue))]
          [(required-stage-order)
           (fprintf out "Required stage order is not present: ~a.\n"
                    (string-join (finding-part issue) " -> "))]
          [(invalid-condition)
           (fprintf out "Invalid condition ~a targeting ~a.\n"
                    (finding-part issue) (finding-target issue))]))))

(module+ main
  (require racket/cmdline)
  (define method-path
    (command-line #:program "sciencelogo-assessor" #:args (method) method))
  (define result (assess-file method-path))
  (render-assessment result)
  (unless (null? (assessment-findings result)) (exit 1)))
