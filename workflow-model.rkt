#lang racket/base

(require file/sha1
         racket/list
         racket/match
         racket/path
         "private/reader.rkt"
         "private/record-interfaces.rkt")

(provide read-workflow-model
         read-interface-model
         (struct-out source-ref)
         (struct-out workflow-model)
         (struct-out stage-model)
         (struct-out performer-model)
         (struct-out resource-model)
         (struct-out proposition-model)
         (struct-out procedure-model)
         (struct-out activity-model)
         (struct-out item-model)
         (struct-out relation-model)
         (struct-out import-model)
         (struct-out implementation-model)
         (struct-out provision-model)
         (struct-out interface-model)
         (struct-out condition-model))

;; These records describe a method. They do not report that any activity occurred.
(struct source-ref (source line column position) #:transparent)
(struct workflow-model (id title source revision procedures stages activities items
                           relations imports implementations conditions performers resources
                           propositions) #:transparent)
(struct stage-model (id name parent source entry exit performer) #:transparent)
(struct performer-model (id name fields source) #:transparent)
(struct resource-model (id name fields source) #:transparent)
(struct proposition-model (id type name fields source) #:transparent)
(struct procedure-model (id name inputs source) #:transparent)
(struct activity-model (id kind name parent source control details) #:transparent)
(struct item-model (id name role scope producer source) #:transparent)
(struct relation-model (kind from to source) #:transparent)
(struct import-model (id url requested-revision commit alias library-name source)
  #:transparent)
(struct implementation-model (id path alias provisions source) #:transparent)
(struct provision-model (id part locator source) #:transparent)
(struct interface-model (id name version source revision conditions relations)
  #:transparent)
(struct condition-model (id kind target scope checkpoint evidence source)
  #:transparent)

(define (origin at)
  (source-ref (format "~a" (token-source at))
              (token-line at)
              (token-column at)
              (token-position at)))

(define (source-revision path)
  (call-with-input-file path sha1))

(define (element-id root kind at [context #f])
  (format "~a#~a~a@~a:~a"
          root kind
          (if context
              (format "/~a" (sha1 (open-input-string (format "~s" context))))
              "")
          (token-source at) (token-position at)))

(define (read-workflow-model path)
  (define source (path->string (path->complete-path path)))
  (define tree (parse-sciencelogo-tree-file source))
  (unless (eq? (node-kind tree) 'workflow)
    (error 'read-workflow-model "~a is not a ScienceLogo investigation" source))
  (define forms (node-children tree))
  ;; Resolved imports and imported definitions contribute to the method identity.
  ;; The latter also captures transitive library dependencies after expansion.
  (define revision
    (sha1
     (open-input-string
      (format "~s"
              (list (source-revision source)
                    (for/list ([form (in-list forms)]
                               #:when (eq? (node-kind form) 'included-file))
                      (node-value form))
                    (for/list ([form (in-list forms)]
                               #:when (eq? (node-kind form) 'import))
                      (node-value form))
                    (for/list ([form (in-list forms)]
                               #:when (and (eq? (node-kind form) 'to)
                                           (not (equal? (format "~a" (token-source (node-at form)))
                                                        source))))
                      (format "~a" (token-source (node-at form)))))))))
  (define root (format "~a@~a" source revision))
  (define definitions
    (filter (lambda (form) (eq? (node-kind form) 'to)) forms))
  (define inline-interfaces
    (for/hasheq ([form (in-list forms)]
                 #:when (eq? (node-kind form) 'interface))
      (values (string->symbol (node-value form)) form)))
  (define procedure-ids
    (for/hasheq ([definition (in-list definitions)])
      (values (car (node-value definition))
              (element-id root 'procedure (node-at definition)
                          (car (node-value definition))))))
  (define performer-declarations
    (filter (lambda (form) (eq? (node-kind form) 'performer)) forms))
  (define performer-ids
    (for/hasheq ([declaration (in-list performer-declarations)])
      (values (node-value declaration)
              (element-id root 'performer (node-at declaration)
                          (node-value declaration)))))
  (define performers
    (for/list ([declaration (in-list performer-declarations)])
      (performer-model
       (hash-ref performer-ids (node-value declaration))
       (node-value declaration)
       (node->datum (first (node-children declaration)))
       (origin (node-at declaration)))))
  (define resource-declarations
    (filter (lambda (form) (eq? (node-kind form) 'resource)) forms))
  (define resource-ids
    (for/hasheq ([declaration (in-list resource-declarations)])
      (values (node-value declaration)
              (element-id root 'resource (node-at declaration)
                          (node-value declaration)))))
  (define resources
    (for/list ([declaration (in-list resource-declarations)])
      (resource-model
       (hash-ref resource-ids (node-value declaration))
       (node-value declaration)
       (node->datum (first (node-children declaration)))
       (origin (node-at declaration)))))
  (define proposition-declarations
    (filter (lambda (form) (eq? (node-kind form) 'proposition)) forms))
  (define proposition-ids
    (for/hash ([declaration (in-list proposition-declarations)])
      (values (node-value declaration)
              (element-id root 'proposition (node-at declaration)
                          (node-value declaration)))))
  (define propositions
    (for/list ([declaration (in-list proposition-declarations)])
      (proposition-model
       (hash-ref proposition-ids (node-value declaration))
       (first (node-value declaration))
       (second (node-value declaration))
       (node->datum (first (node-children declaration)))
       (origin (node-at declaration)))))
  (define (path-root value)
    (case (node-kind value)
      [(result) (node-value value)]
      [(field-ref dot-select) (path-root (car (node-children value)))]
      [else #f]))
  (define (proposition-key value)
    (define (parts node)
      (case (node-kind node)
        [(result) (list (node-value node))]
        [(field-ref)
         (append (parts (first (node-children node)))
                 (list (node-value node)))]
        [(dot-select) (parts (first (node-children node)))]
        [else '()]))
    (match (parts value)
      [(list* 'hypotheses name _) (list 'hypothesis name)]
      [(list* 'assumptions name _) (list 'assumption name)]
      [(list* 'conclusions name _) (list 'conclusion name)]
      [_ #f]))
  (define (resource-path? value)
    (and (memq (node-kind value) '(field-ref dot-select))
         (hash-has-key? resource-ids (path-root value))))
  (define current-performer (make-parameter #f))
  (define in-state-stage (make-parameter #f))
  (define procedures '())
  (define stages '())
  (define activities '())
  (define items '())
  (define relations '())
  (define imports '())
  (define implementations '())
  (define conditions '())
  (define update-sites (make-hash))
  (define (add-relation kind from to at)
    (set! relations (cons (relation-model kind from to (origin at)) relations)))
  (define (add-activity form parent [name #f])
    (define id (element-id root (node-kind form) (node-at form) parent))
    (define control
      (case (node-kind form)
        [(repeat repeat-until while branch)
         (and (node-value form) (node->datum (node-value form)))]
        [(for-each) (node->datum (cdr (node-value form)))]
        [else #f]))
    (define effective-performer
      (case (node-kind form)
        [(state-call) (or (third (node-value form)) (current-performer))]
        [(assignment path-assignment)
         (and (current-performer)
              (or (and (eq? (node-kind form) 'assignment)
                       (resource-path? (cdr (node-value form))))
                  (and (eq? (node-kind form) 'path-assignment)
                       (or (resource-path? (first (node-children form)))
                           (resource-path? (second (node-children form))))))
              (current-performer))]
        [else #f]))
    (define activity
      (activity-model id (node-kind form) name parent
                      (origin (node-at form)) control #f))
    (set! activities
          (cons (case (node-kind form)
                  [(state-call)
                   (struct-copy activity-model activity
                                [details
                                 (list (for/list ([mapping (in-list (node-children form))])
                                         (list (node-value mapping)
                                               (node-value (car (node-children mapping)))))
                                       (node-value (second (node-value form)))
                                       effective-performer)])]
                  [(call assignment path-assignment path-update-command print output)
                   (struct-copy activity-model activity
                                [details (node->datum form)])]
                  [else activity])
                activities))
    (add-relation 'contains parent id (node-at form))
    (when effective-performer
      (add-relation 'performed-by id
                    (hash-ref performer-ids effective-performer)
                    (node-at form)))
    id)
  (define (resolve-item value inputs scopes)
    (case (node-kind value)
      [(literal) #f]
      [(parameter) (hash-ref inputs (node-value value))]
      [(result)
       (cond
         [(memq (node-value value) '(hypotheses assumptions conclusions)) #f]
         [(or (hash-has-key? inline-interfaces (node-value value))
              (hash-has-key? performer-ids (node-value value))
              (and (in-state-stage)
                   (memq (node-value value)
                         '(information environment factors))))
          #f]
         [else
          (let loop ([remaining scopes])
            (cond
              [(null? remaining)
               (error 'read-workflow-model "unresolved result ~a"
                      (node-value value))]
              [(hash-has-key? (car remaining) (node-value value))
               (hash-ref (car remaining) (node-value value))]
              [else (loop (cdr remaining))]))])]))
  (define (add-use activity-id value inputs scopes)
    (define key (proposition-key value))
    (cond
      [(resource-path? value)
       (add-relation 'reads-from activity-id
                     (hash-ref resource-ids (path-root value)) (node-at value))]
      [(and key (hash-has-key? proposition-ids key))
       (add-relation 'uses activity-id
                     (hash-ref proposition-ids key) (node-at value))]
      [else
       (case (node-kind value)
         [(list fields field-entry proposition-value uncertain field-ref range compare
                binary unary augment dot-update)
          (for ([part (in-list (node-children value))])
            (add-use activity-id part inputs scopes))]
         [(dot-select)
          (add-use activity-id (car (node-children value)) inputs scopes)]
         [else
          (define item-id (resolve-item value inputs scopes))
          (when item-id
            (add-relation 'uses activity-id item-id (node-at value))
            (define producer
              (for/first ([item (in-list items)]
                          #:when (equal? (item-model-id item) item-id))
                (item-model-producer item)))
            (when producer
              (add-relation 'depends-on activity-id producer (node-at value)))
            (for ([updater (in-list (hash-ref update-sites item-id '()))])
              (add-relation 'depends-on activity-id updater (node-at value))))])]))
  (define (build-block body parent inputs scopes)
    (define previous #f)
    (define current-stage #f)
    (for ([form (in-list body)])
      (define kind (node-kind form))
      (cond
        [(eq? kind 'stage)
         (define id (element-id root 'stage (node-at form) parent))
         (set! stages
               (cons (stage-model id (node-value form) parent
                                  (origin (node-at form)) #f #f #f)
                     stages))
         (add-relation 'contains parent id (node-at form))
         (set! current-stage id)]
        [(eq? kind 'state-stage)
         (define id (element-id root 'stage (node-at form) parent))
         (set! stages
               (cons (stage-model id (car (node-value form)) parent
                                  (origin (node-at form))
                                  (node->datum (second (node-value form)))
                                  (node->datum (third (node-value form)))
                                  (fourth (node-value form)))
                     stages))
         (add-relation 'contains parent id (node-at form))
         (parameterize ([current-performer (fourth (node-value form))]
                        [in-state-stage #t])
           (build-block (node-children form) id inputs scopes))
         (set! current-stage #f)]
        [(memq kind '(call state-call sequence repeat repeat-until for-each while if
                           assignment path-assignment path-update-command print output))
         (define section (or current-stage parent))
         (define name (and (memq kind '(call state-call))
                           (car (node-value form))))
         (define id (add-activity form section name))
         (when previous
           (add-relation 'precedes previous id (node-at form)))
         (set! previous id)
         (case kind
           [(sequence)
            (build-block (node-children form) id inputs
                         (cons (make-hasheq) scopes))]
           [(repeat)
            (add-use id (node-value form) inputs scopes)
            (build-block (node-children form) id inputs
                         (cons (make-hasheq) scopes))]
           [(while)
            (add-use id (node-value form) inputs scopes)
            (build-block (node-children form) id inputs
                         (cons (make-hasheq) scopes))]
           [(repeat-until)
            (define local-scope (make-hasheq))
            (build-block (node-children form) id inputs
                         (cons local-scope scopes))
            (add-use id (node-value form) inputs
                     (cons local-scope scopes))]
           [(if)
            (for ([branch (in-list (node-children form))])
              (define branch-id (add-activity branch id))
              (when (node-value branch)
                (add-use branch-id (node-value branch) inputs scopes))
              (build-block (node-children branch) branch-id inputs
                           (cons (make-hasheq) scopes)))]
           [(for-each)
            (add-use id (cdr (node-value form)) inputs scopes)
            (define name (car (node-value form)))
            (define item-id (format "~a/iteration:~a" id name))
            (set! items
                  (cons (item-model item-id name 'iteration id id
                                    (origin (node-at form)))
                        items))
            (add-relation 'contains id item-id (node-at form))
            (add-relation 'produces id item-id (node-at form))
            (define loop-scope (make-hasheq))
            (hash-set! loop-scope name item-id)
            (build-block (node-children form) id inputs
                         (cons loop-scope scopes))]
           [(assignment)
            (add-use id (cdr (node-value form)) inputs scopes)
            (define name (car (node-value form)))
            (define existing
              (for/first ([scope (in-list scopes)]
                          #:when (hash-has-key? scope name))
                (hash-ref scope name)))
            (if existing
                (begin
                  (add-relation 'updates id existing (node-at form))
                  (hash-update! update-sites existing
                                (lambda (sites) (cons id sites)) '()))
                (let ([item-id (format "~a/value:~a" id name)])
                  (set! items
                        (cons (item-model item-id name 'value section id
                                          (origin (node-at form)))
                              items))
                  (hash-set! (car scopes) name item-id)
                  (add-relation 'contains section item-id (node-at form))
                  (add-relation 'produces id item-id (node-at form))))]
           [(path-assignment path-update-command)
            (define target (car (node-children form)))
            (define (root value)
              (if (eq? (node-kind value) 'result)
                  (node-value value)
                  (root (car (node-children value)))))
            (define name (root target))
            (if (resource-path? target)
                (add-relation 'writes-to id (hash-ref resource-ids name)
                              (node-at target))
                (add-use id target inputs scopes))
            (when (eq? kind 'path-assignment)
              (add-use id (second (node-children form)) inputs scopes))
            (define existing
              (for/first ([scope (in-list scopes)]
                          #:when (hash-has-key? scope name))
                (hash-ref scope name)))
            (when existing
              (add-relation 'updates id existing (node-at form))
              (hash-update! update-sites existing
                            (lambda (sites) (cons id sites)) '()))
            (when (memq name '(hypotheses assumptions conclusions))
              (define (first-child value)
                (case (node-kind value)
                  [(field-ref)
                   (define receiver (first (node-children value)))
                   (if (eq? (node-kind receiver) 'result)
                       (node-value value)
                       (first-child receiver))]
                  [else #f]))
              (define child (first-child target))
              (define type
                (case name
                  [(hypotheses) 'hypothesis]
                  [(assumptions) 'assumption]
                  [(conclusions) 'conclusion]))
              (when (hash-has-key? proposition-ids (list type child))
                (add-relation 'updates id
                              (hash-ref proposition-ids (list type child))
                              (node-at form))))]
           [(call)
            (add-relation 'invokes id (hash-ref procedure-ids name) (node-at form))
            (for ([argument (in-list (node-children form))])
              (add-use id argument inputs scopes))
            (define result-name (cdr (node-value form)))
            (when result-name
              (define item-id (format "~a/result:~a" id result-name))
              (set! items
                    (cons (item-model item-id result-name 'result section id
                                      (origin (node-at form)))
                          items))
              (hash-set! (car scopes) result-name item-id)
              (add-relation 'contains section item-id (node-at form))
              (add-relation 'produces id item-id (node-at form)))]
           [(state-call)
            (add-relation 'invokes id (hash-ref procedure-ids name) (node-at form))]
           [(print output)
            (add-use id (node-value form) inputs scopes)])]
        [else (void)])))
  (for ([definition (in-list definitions)])
    (define id (hash-ref procedure-ids (car (node-value definition))))
    (define input-map (make-hasheq))
    (define input-ids
      (for/list ([name (in-list (cdr (node-value definition)))])
        (define item-id (format "~a/input:~a" id name))
        (hash-set! input-map name item-id)
        (set! items
              (cons (item-model item-id name 'input id #f
                                (origin (node-at definition)))
                    items))
        (add-relation 'contains id item-id (node-at definition))
        item-id))
    (set! procedures
          (cons (procedure-model id (car (node-value definition)) input-ids
                                 (origin (node-at definition)))
                procedures))
    (add-relation
     (if (equal? (format "~a" (token-source (node-at definition))) source)
         'defines 'imports)
     root id (node-at definition))
    (build-block (node-children definition) id input-map
                 (list (make-hasheq))))
  (for ([form (in-list forms)])
    (case (node-kind form)
      [(performer)
       (add-relation 'defines-performer root
                     (hash-ref performer-ids (node-value form))
                     (node-at form))]
      [(resource)
       (add-relation 'defines-resource root
                     (hash-ref resource-ids (node-value form))
                     (node-at form))]
      [(proposition)
       (add-relation 'defines-proposition root
                     (hash-ref proposition-ids (node-value form))
                     (node-at form))]
      [(import)
       (match-define (list url requested commit alias library-name)
         (node-value form))
       (define id (element-id root 'import (node-at form) alias))
       (set! imports
             (cons (import-model id url requested commit alias library-name
                                 (origin (node-at form)))
                   imports))
       (add-relation 'imports root id (node-at form))]
      [(implements)
       (match-define (list interface-path alias) (node-value form))
       (define id (element-id root 'implements (node-at form)))
       (define provisions
         (for/list ([provided (in-list (node-children form))])
           (match-define (list part locator) (node-value provided))
           (provision-model (element-id root 'provide (node-at provided))
                            part locator (origin (node-at provided)))))
       (set! implementations
             (cons (implementation-model id interface-path alias provisions
                                         (origin (node-at form)))
                   implementations))
       (add-relation 'claims-implementation root id (node-at form))]
      [(must-call)
       (set! conditions
             (cons (condition-model (element-id root 'must-do (node-at form))
                                    'required-call
                                    (hash-ref procedure-ids (node-value form))
                                    root 'method 'method-paths
                                    (origin (node-at form)))
                   conditions))]
      [(must-stage-order)
       (set! conditions
             (cons (condition-model (element-id root 'must-stage-order (node-at form))
                                    'stage-order (node-value form)
                                    root 'method 'stage-headers
                                    (origin (node-at form)))
                   conditions))]
      [(must-implement)
       (define reference (cadr (node-value form)))
       (define earlier
         (takef forms (lambda (candidate) (not (eq? candidate form)))))
       (set! conditions
             (cons (condition-model (element-id root 'must-implement (node-at form))
                                    'record-implementation (car (node-value form))
                                    root 'method
                                    (list reference
                                          (map node->datum earlier)
                                          (and (symbol? reference)
                                               (node->datum
                                                (hash-ref inline-interfaces
                                                          (interface-reference-root
                                                           inline-interfaces reference))))
                                          (for/list ([declaration (in-hash-values inline-interfaces)])
                                            (node->datum declaration)))
                                    (origin (node-at form)))
                   conditions))]))
  (build-block forms root (make-hasheq) (list (make-hasheq)))
  (workflow-model root (node-value tree) source revision
                  (reverse procedures) (reverse stages) (reverse activities) (reverse items)
                  (reverse relations) (reverse imports)
                  (reverse implementations) (reverse conditions) performers resources
                  propositions))

(define (read-interface-model path)
  (define source (path->string (path->complete-path path)))
  (define tree (parse-sciencelogo-tree-file source))
  (unless (eq? (node-kind tree) 'interface)
    (error 'read-interface-model "~a is not a ScienceLogo interface" source))
  (define revision (source-revision source))
  (define id (format "~a@~a" source revision))
  (define forms (node-children tree))
  (define version
    (let ([declared (findf (lambda (form) (eq? (node-kind form) 'version)) forms)])
      (and declared (node-value declared))))
  (define conditions '())
  (define relations '())
  (define effects '())
  (define (qualified prefix name)
    (string->symbol (string-append prefix (symbol->string name))))
  (define (walk forms scope [prefix ""])
    (for ([form (in-list forms)])
      (case (node-kind form)
        [(interface-field required-interface-field interface-group required-interface-group)
         (define name (qualified prefix (node-value form)))
         (define child-id (element-id id 'field (node-at form)))
         (define group? (memq (node-kind form) '(interface-group required-interface-group)))
         (set! conditions
               (cons (condition-model child-id
                                      (if (memq (node-kind form)
                                                '(required-interface-field required-interface-group))
                                          'required-entry 'optional-entry)
                                      name scope 'interface
                                      (if group? 'nested-entries
                                          (and (pair? (node-children form))
                                               (node->datum (car (node-children form)))))
                                      (origin (node-at form)))
                     conditions))
         (unless (equal? scope id)
           (set! relations (cons (relation-model 'contains scope child-id (origin (node-at form)))
                                 relations)))
         (when group? (walk (node-children form) child-id (string-append (symbol->string name) ".")))]
        [(affects) (set! effects (cons (cons prefix form) effects))])))
  (walk forms id)
  (set! conditions (reverse conditions))
  (define condition-ids
    (for/hasheq ([condition (in-list conditions)])
      (values (condition-model-target condition)
              (condition-model-id condition))))
  (for ([effect (in-list (reverse effects))])
    (define prefix (car effect))
    (define form (cdr effect))
    (match-define (list from to) (node-value form))
    (set! relations
          (cons (relation-model 'affects (hash-ref condition-ids (qualified prefix from))
                                (hash-ref condition-ids (qualified prefix to))
                                (origin (node-at form))) relations)))
  (interface-model id (node-value tree) version source revision
                   conditions (reverse relations)))
