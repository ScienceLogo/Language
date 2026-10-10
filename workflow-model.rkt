#lang racket/base

(require file/sha1
         racket/list
         racket/match
         racket/path
         "private/reader.rkt")

(provide read-workflow-model
         read-interface-model
         (struct-out source-ref)
         (struct-out workflow-model)
         (struct-out stage-model)
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
                           relations imports implementations conditions) #:transparent)
(struct stage-model (id name parent source) #:transparent)
(struct procedure-model (id name inputs source) #:transparent)
(struct activity-model (id kind name parent source) #:transparent)
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
  (define procedure-ids
    (for/hasheq ([definition (in-list definitions)])
      (values (car (node-value definition))
              (element-id root 'procedure (node-at definition)
                          (car (node-value definition))))))
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
    (set! activities
          (cons (activity-model id (node-kind form) name parent
                                (origin (node-at form)))
                activities))
    (add-relation 'contains parent id (node-at form))
    id)
  (define (resolve-item value inputs scopes)
    (case (node-kind value)
      [(literal) #f]
      [(parameter) (hash-ref inputs (node-value value))]
      [(result)
       (let loop ([remaining scopes])
         (cond
           [(null? remaining)
            (error 'read-workflow-model "unresolved result ~a" (node-value value))]
           [(hash-has-key? (car remaining) (node-value value))
            (hash-ref (car remaining) (node-value value))]
           [else (loop (cdr remaining))]))]))
  (define (add-use activity-id value inputs scopes)
    (case (node-kind value)
      [(list range compare)
       (for ([part (in-list (node-children value))])
         (add-use activity-id part inputs scopes))]
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
           (add-relation 'depends-on activity-id updater (node-at value))))]))
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
                                  (origin (node-at form)))
                     stages))
         (add-relation 'contains parent id (node-at form))
         (set! current-stage id)]
        [(memq kind '(call sequence repeat repeat-until for-each while if set print output))
         (define section (or current-stage parent))
         (define name (and (eq? kind 'call) (car (node-value form))))
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
           [(set)
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
                                    'reachable-call
                                    (hash-ref procedure-ids (node-value form))
                                    root 'method 'reachable-call
                                    (origin (node-at form)))
                   conditions))]
      [(must-stage-order)
       (set! conditions
             (cons (condition-model (element-id root 'must-stage-order (node-at form))
                                    'stage-order (node-value form)
                                    root 'method 'stage-headers
                                    (origin (node-at form)))
                   conditions))]))
  (build-block forms root (make-hasheq) (list (make-hasheq)))
  (workflow-model root (node-value tree) source revision
                  (reverse procedures) (reverse stages) (reverse activities) (reverse items)
                  (reverse relations) (reverse imports)
                  (reverse implementations) (reverse conditions)))

(define (read-interface-model path)
  (define source (path->string (path->complete-path path)))
  (define tree (parse-sciencelogo-tree-file source))
  (unless (eq? (node-kind tree) 'interface)
    (error 'read-interface-model "~a is not a ScienceLogo interface" source))
  (define revision (source-revision source))
  (define id (format "~a@~a" source revision))
  (define forms (node-children tree))
  (define version
    (node-value (findf (lambda (form) (eq? (node-kind form) 'version)) forms)))
  (define conditions
    (for/list ([form (in-list forms)] #:when (eq? (node-kind form) 'require))
      (condition-model (element-id id 'require (node-at form))
                       'provided-part (node-value form) id 'method
                       'provide-declaration (origin (node-at form)))))
  (define condition-ids
    (for/hasheq ([condition (in-list conditions)])
      (values (condition-model-target condition)
              (condition-model-id condition))))
  (define relations
    (for/list ([form (in-list forms)] #:when (eq? (node-kind form) 'affects))
      (match-define (list from to) (node-value form))
      (relation-model 'affects (hash-ref condition-ids from)
                      (hash-ref condition-ids to) (origin (node-at form)))))
  (interface-model id (node-value tree) version source revision
                   conditions relations))
