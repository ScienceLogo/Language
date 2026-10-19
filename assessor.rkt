#lang racket/base

(require racket/list
         racket/match
         racket/path
         racket/string
         "private/call-paths.rkt"
         "private/record-interfaces.rkt"
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
         [(required-call)
          (and (eq? (type-of (condition-model-target condition)) 'procedure)
               (eq? (condition-model-evidence condition) 'method-paths))]
         [(stage-order)
          (and (stage-order-target? (condition-model-target condition))
               (eq? (condition-model-evidence condition) 'stage-headers))]
         [(record-implementation)
          (and (symbol? (condition-model-target condition))
               (list? (condition-model-evidence condition))
               (= (length (condition-model-evidence condition)) 4))]
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
  (for ([performer (in-list (workflow-model-performers method))])
    (register (performer-model-id performer) 'performer performer))
  (for ([resource (in-list (workflow-model-resources method))])
    (register (resource-model-id resource) 'resource resource))
  (for ([proposition (in-list (workflow-model-propositions method))])
    (register (proposition-model-id proposition) 'proposition proposition))
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
                  (memq (activity-kind from)
                        '(sequence repeat repeat-until for-each while if branch)))
              (memq to-type '(stage activity item))
              (equal? from (parent-of to)))]
        [(defines) (and (eq? from-type 'workflow) (eq? to-type 'procedure))]
        [(defines-performer)
         (and (eq? from-type 'workflow) (eq? to-type 'performer))]
        [(defines-resource)
         (and (eq? from-type 'workflow) (eq? to-type 'resource))]
        [(defines-proposition)
         (and (eq? from-type 'workflow) (eq? to-type 'proposition))]
        [(reads-from writes-to)
         (and (eq? from-type 'activity) (eq? to-type 'resource))]
        [(performed-by)
         (and (memq (activity-kind from) '(state-call assignment path-assignment))
              (eq? to-type 'performer))]
        [(imports)
         (and (eq? from-type 'workflow) (memq to-type '(import procedure)))]
        [(claims-implementation)
         (and (eq? from-type 'workflow) (eq? to-type 'implementation))]
        [(invokes)
         (and (memq (activity-kind from) '(call state-call))
              (eq? to-type 'procedure))]
        [(uses)
         (and (eq? from-type 'activity) (memq to-type '(item proposition)))]
        [(produces)
         (and (memq (activity-kind from) '(call for-each assignment)) (eq? to-type 'item)
              (equal? (item-model-producer (cdr (hash-ref elements to))) from))]
        [(updates)
         (and (memq (activity-kind from)
                    '(assignment path-assignment path-update-command))
              (or (eq? to-type 'proposition)
                  (and (eq? to-type 'item)
                       (eq? (item-model-role (cdr (hash-ref elements to))) 'value))))]
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
  (define procedures
    (for/hash ([procedure (in-list (workflow-model-procedures method))])
      (values (procedure-model-id procedure) procedure)))
  (define checks '())
  (define findings '())
  (for ([condition (in-list (workflow-model-conditions method))]
        #:when (and (eq? (condition-model-kind condition) 'required-call)
                    (hash-has-key? procedures (condition-model-target condition))
                    (equal? (condition-model-scope condition)
                            (workflow-model-id method))
                    (eq? (condition-model-checkpoint condition) 'method)
                    (eq? (condition-model-evidence condition) 'method-paths)))
    (define target (condition-model-target condition))
    (define-values (outcome calls) (required-call-paths method target))
    (set! checks
          (cons (condition-check (condition-model-id condition) target
                                 outcome calls
                                 (case outcome
                                   [(satisfied) #f]
                                   [(undetermined) 'conditional-call]
                                   [else 'missing-required-call]))
                checks))
    (unless (eq? outcome 'satisfied)
      (set! findings
            (cons (finding (if (eq? outcome 'undetermined)
                               'conditional-required-call
                               'missing-required-call)
                           #f (procedure-model-name (hash-ref procedures target))
                           '() (condition-model-id condition) target outcome
                           (if (eq? outcome 'undetermined)
                               calls
                               (list (condition-model-source condition))))
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
    (simplify-path (build-path
                    (path-only (source-ref-source
                                (implementation-model-source declaration)))
                    (string->path path))))
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
  (define interface (read-interface-model interface-path))
  (if (for/or ([condition (in-list (interface-model-conditions interface))])
        (eq? (condition-model-kind condition) 'required-field))
      (values
       (assessed-interface (implementation-model-alias declaration)
                           (interface-model-name interface)
                           (interface-model-version interface) interface-path
                           (interface-model-id interface)
                           (interface-model-revision interface))
       (list (finding 'wrong-interface-kind
                      (implementation-model-alias declaration)
                      interface-path '()
                      'sciencelogo:workflow-part-interface
                      (implementation-model-id declaration) 'violated
                      (list (implementation-model-source declaration))))
       '())
      (assess-workflow-parts declaration interface-path interface)))

(define (assess-workflow-parts declaration interface-path interface)
  (define alias (implementation-model-alias declaration))
  (define provisions (implementation-model-provisions declaration))
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

(define (shape-put shape path value)
  (define name (car path))
  (if (null? (cdr path))
      (hash-set shape name value)
      (hash-set shape name
                (shape-put (let ([earlier (hash-ref shape name #f)])
                             (if (hash? earlier) earlier (hasheq)))
                           (cdr path) value))))

(define (shape-merge base changes)
  (for/fold ([result base]) ([(name value) (in-hash changes)])
    (define earlier (hash-ref result name #f))
    (hash-set result name
              (if (and (hash? earlier) (hash? value))
                  (shape-merge earlier value)
                  value))))

(define (shape-has-path? shape path)
  (and (hash? shape)
       (hash-has-key? shape (car path))
       (or (null? (cdr path))
           (shape-has-path? (hash-ref shape (car path)) (cdr path)))))

(define (record-shape expression environment templates)
  ;; Only written, direct record constructions are known here. A procedure result
  ;; or an executable block can depend on information absent from the method.
  (match expression
    [`(fields ,entries)
     (for/hasheq ([entry (in-list entries)])
       (values (car entry)
               (if (and (pair? (cadr entry)) (eq? (caadr entry) 'fields))
                   (record-shape (cadr entry) environment templates)
                   #t)))]
    [`(result ,name)
     (hash-ref environment name 'undetermined)]
    [`(dot-update (,source (fields ,entries)))
     (define base
       (match source
         [`(result ,name)
          (if (hash-has-key? templates name)
              (for/fold ([shape (hasheq)])
                        ([field (in-list
                                 (record-interface-fields
                                  (hash-ref templates name)))]
                         #:when (cdr field))
                (shape-put shape
                           (map string->symbol
                                (string-split (symbol->string (car field)) "."))
                           #t))
              (hash-ref environment name 'undetermined))]
         [_ (record-shape source environment templates)]))
     (if (hash? base)
         (shape-merge base
                      (record-shape `(fields ,entries) environment templates))
         base)]
    [`(augment ,_ (,source ,changes))
     (define base (record-shape source environment templates))
     (define added (record-shape changes environment templates))
     (if (and (hash? base) (hash? added))
         (shape-merge base added)
         'undetermined)]
    [`(literal ,_) 'not-a-record]
    [_ 'undetermined]))

(define (assess-record-condition condition method)
  (match-define (list reference earlier local declarations)
    (condition-model-evidence condition))
  (define templates
    (resolve-record-interfaces
     (for/hasheq ([declaration (in-list declarations)])
       (match-define `(interface ,name ,parts) declaration)
       (values (string->symbol name) parts))))
  (define method-source (workflow-model-source method))
  (define interface-path
    (and (string? reference)
         (simplify-path (build-path (path-only (source-ref-source
                                               (condition-model-source condition)))
                                    (string->path reference)))))
  (define interface
    (cond
      [(symbol? reference)
       (define parts (caddr local))
       (define version
         (for/first ([part (in-list parts)] #:when (eq? (car part) 'version))
           (cadr part)))
       (interface-model (format "~a/interface:~a" (workflow-model-id method)
                                reference)
                        (cadr local) version method-source
                        (workflow-model-revision method)
                        (for/list ([field (in-list
                                           (record-interface-fields
                                            (hash-ref templates reference)))])
                          (condition-model #f 'required-field (car field) #f #f
                                           (cdr field) #f))
                        '())]
      [(file-exists? interface-path) (read-interface-model interface-path)]
      [else #f]))
  (define condition-id (condition-model-id condition))
  (define target (condition-model-target condition))
  (cond
    [(not interface)
     (values #f
             (list (finding 'missing-interface-file reference reference '()
                            condition-id target 'violated
                            (list (condition-model-source condition))))
             (list (condition-check condition-id target 'violated '()
                                    'missing-interface-file)))]
    [else
     (define record-interface?
       (andmap (lambda (part) (eq? (condition-model-kind part) 'required-field))
               (interface-model-conditions interface)))
     (define assessed
       (assessed-interface reference (interface-model-name interface)
                           (interface-model-version interface)
                           (interface-model-source interface)
                           (interface-model-id interface)
                           (interface-model-revision interface)))
     (define environment (make-hasheq))
     (for ([form (in-list earlier)])
       (match form
         [`(assignment ,name ,expression)
          (hash-set! environment name
                     (record-shape expression environment templates))]
         [`(path-assignment ,target ,_)
          (define (path value)
            (match value
              [`(result ,name) (list name)]
              [`(field-ref ,field ,receiver)
               (append (path receiver) (list field))]
              [_ #f]))
          (define location (path target))
          (when (and location (hash? (hash-ref environment (car location) #f)))
            (hash-set! environment (car location)
                       (shape-put (hash-ref environment (car location))
                                  (cdr location) #t)))]
         [`(path-update-command (dot-update (,receiver (fields ,entries))))
          (match receiver
            [`(result ,name)
             (define earlier (hash-ref environment name 'undetermined))
             (when (hash? earlier)
               (hash-set! environment name
                          (shape-merge earlier
                                       (record-shape `(fields ,entries)
                                                     environment templates))))]
            [_ (void)])]
         [`(call ,_ ,_ ,name)
          (when name (hash-set! environment name 'undetermined))]
         [`(sequence ,_) (for ([name (in-hash-keys environment)])
                           (hash-set! environment name 'undetermined))]
         [`(repeat ,_ ,_) (for ([name (in-hash-keys environment)])
                          (hash-set! environment name 'undetermined))]
         [`(repeat-until ,_ ,_) (for ([name (in-hash-keys environment)])
                                (hash-set! environment name 'undetermined))]
         [`(for-each ,_ ,_ ,_) (for ([name (in-hash-keys environment)])
                               (hash-set! environment name 'undetermined))]
         [`(while ,_ ,_) (for ([name (in-hash-keys environment)])
                          (hash-set! environment name 'undetermined))]
         [`(if ,_) (for ([name (in-hash-keys environment)])
                     (hash-set! environment name 'undetermined))]
         [_ (void)]))
     (define target-parts
       (map string->symbol (string-split (symbol->string target) ".")))
     (define shape
       (for/fold ([current (hash-ref environment (car target-parts)
                                    'undetermined)])
                 ([part (in-list (cdr target-parts))])
         (if (hash? current)
             (hash-ref current part 'undetermined)
             'undetermined)))
     (define missing
       (and (hash? shape)
            (for/list ([part (in-list (interface-model-conditions interface))]
                       #:unless (shape-has-path?
                                 shape
                                 (map string->symbol
                                      (string-split
                                       (symbol->string (condition-model-target part))
                                       "."))))
              (condition-model-target part))))
     (define-values (outcome gap)
       (cond [(not record-interface?) (values 'violated 'wrong-interface-kind)]
             [(eq? shape 'undetermined) (values 'undetermined 'unknown-record)]
             [(eq? shape 'not-a-record) (values 'violated 'not-a-record)]
             [(pair? missing) (values 'violated 'missing-field)]
             [else (values 'satisfied #f)]))
     (define evidence
       (list (interface-model-id interface) (interface-model-revision interface)))
     (values assessed
             (if gap
                 (list (finding gap reference (if (pair? missing) missing target)
                                '() condition-id target outcome evidence))
                 '())
             (list (condition-check condition-id target outcome evidence gap)))]))

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
  (for ([condition (in-list (workflow-model-conditions method))]
        #:when (eq? (condition-model-kind condition) 'record-implementation))
    (define-values (interface issues results)
      (assess-record-condition condition method))
    (when (and interface
               (not (for/or ([existing (in-list interfaces)])
                      (equal? (assessed-interface-id existing)
                              (assessed-interface-id interface)))))
      (set! interfaces (append interfaces (list interface))))
    (set! findings (append findings issues))
    (set! checks (append checks results)))
  (assessment (or (workflow-model-title method) (workflow-model-source method))
              (workflow-model-source method)
              interfaces findings checks method))

(define (assess-file path)
  (assess-workflow (read-workflow-model path)))

(define (render-assessment result [out (current-output-port)])
  (fprintf out "ScienceLogo assessment: ~a\n" (assessment-title result))
  (for ([interface (in-list (assessment-interfaces result))])
    (fprintf out "Interface ~a: ~a, ~a (~a; revision ~a)\n"
             (assessed-interface-alias interface)
             (assessed-interface-name interface)
             (if (assessed-interface-version interface)
                 (format "version ~a" (assessed-interface-version interface))
                 "unversioned")
             (assessed-interface-source interface)
             (assessed-interface-revision interface)))
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
           (fprintf out "Required call to ~a is absent from feasible method paths.\n"
                    (finding-part issue))]
          [(conditional-required-call)
           (fprintf out "Required call to ~a is conditional in the written method.\n"
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
                    (finding-part issue) (finding-target issue))]
          [(missing-field)
           (fprintf out "Record ~a is missing field(s) ~a required by ~a.\n"
                    (finding-target issue) (finding-part issue)
                    (finding-interface issue))]
          [(unknown-record)
           (fprintf out "Record ~a cannot be checked from the written method.\n"
                    (finding-target issue))]
          [(not-a-record)
           (fprintf out "Value ~a is not a record.\n" (finding-target issue))]
          [(wrong-interface-kind)
           (fprintf out "Interface ~a does not describe record fields.\n"
                    (finding-interface issue))]))))

(module+ main
  (require racket/cmdline)
  (define method-path
    (command-line #:program "sciencelogo-assessor" #:args (method) method))
  (define result (assess-file method-path))
  (render-assessment result)
  (unless (null? (assessment-findings result)) (exit 1)))
