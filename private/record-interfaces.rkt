#lang racket/base

(require racket/list racket/match racket/string "constant-values.rkt" "uncertain-values.rkt"
         "value-kinds.rkt")

(provide (struct-out record-interface)
         (struct-out record-field)
         (struct-out record-requirement)
         (struct-out requirement-result)
         resolve-record-interfaces
         interface-reference-root
         resolve-interface-reference
         resolve-interface-target
         interface-record
         complete-interface-record
         missing-interface-fields
         undetermined-interface-fields
         unknown-interface-fields
         wrong-kind-interface-fields
         interface-requirement-results
         requirement-references
         requirement-entry-references
         interface-guard-value
         interface-value
         iteration-template
         combine-interface-guards
         interface-branch-guards)

;; The caller evaluates defaults in its own value environment.
(struct record-interface (name fields requirements) #:transparent)
(struct record-field (name default required? children guard requirements) #:transparent)
(struct record-requirement (expression guard) #:transparent)
(struct requirement-result (scope expression outcome missing) #:transparent)

;; A requirement's names refer to entries of its surrounding interface part.
(define (requirement-references expression)
  (define references '())
  (define (path expression)
    (match expression
      [`(result ,name) (list name)]
      [`(field-ref ,name ,receiver)
       (define parent (path receiver))
       (and parent (append parent (list name)))]
      [_ #f]))
  (define (walk expression)
    (define location (path expression))
    (cond [location (set! references (cons location references))]
          [(pair? expression)
           (match expression
             [`(literal ,_) (void)]
             [`(interface-for-each ,_ ,collection ,_) (walk collection)]
             [`(fields ,entries) (for ([entry (in-list entries)]) (walk (cadr entry)))]
             [`(dot-select (,receiver ,selectors ...))
              (walk receiver)
              (for ([selector (in-list selectors)] #:unless (eq? (car selector) 'result))
                (walk selector))]
             [_ (for ([part (in-list expression)]) (walk part))])]))
  (walk expression)
  (remove-duplicates (reverse references)))

;; A list's count is derived from its container, not a separately supplied part.
(define (requirement-entry-references expression)
  (remove-duplicates
   (for/list ([path (in-list (requirement-references expression))])
     (define position (index-of (cdr path) 'count))
     (if position (take path (add1 position)) path))))

;; Declarations map interface names to reader datums: (extends Parent) and
;; (interface-field name default-or-#f required? children-or-#f), conditional
;; branches, and (interface-requirement expression).
;; A named group has child declarations; a value field has #f children.
(define (interface-reference-root declarations reference)
  (define text (symbol->string reference))
  (for/first ([name (in-list (sort (hash-keys declarations) >
                                 #:key (lambda (name) (string-length (symbol->string name)))))]
              #:when (or (eq? name reference)
                         (string-prefix? text (string-append (symbol->string name) "."))))
    name))

(define (resolve-interface-reference interfaces reference)
  (define root (interface-reference-root interfaces reference))
  (and root
       (let walk ([interface (hash-ref interfaces root)]
                  [remaining (substring (symbol->string reference)
                                        (string-length (symbol->string root)))])
         (cond
           [(string=? remaining "") interface]
           [else
            (define text (substring remaining 1))
            (define group
              (for/first ([field (in-list (sort (record-interface-fields interface) >
                                              #:key (lambda (field)
                                                      (string-length (symbol->string
                                                                      (record-field-name field))))))]
                          #:when (and (record-field-children field)
                                      (or (string=? text (symbol->string (record-field-name field)))
                                          (string-prefix? text
                                                          (string-append
                                                           (symbol->string (record-field-name field)) ".")))))
                field))
            (and group
                 (walk (record-interface
                        (string-append (record-interface-name interface) "."
                                       (symbol->string (record-field-name group)))
                        (record-field-children group)
                        (record-field-requirements group))
                       (substring text (string-length (symbol->string
                                                        (record-field-name group))))))]))))

(define (resolve-interface-target interfaces reference)
  (or (resolve-interface-reference interfaces reference)
      (let ([root (interface-reference-root interfaces reference)])
        (and root
             (let walk ([fields (record-interface-fields (hash-ref interfaces root))]
                        [path (substring (symbol->string reference)
                                         (add1 (string-length (symbol->string root))))])
               (for/or ([field (in-list fields)])
                 (define name (symbol->string (record-field-name field)))
                 (cond [(string=? name path) field]
                       [(and (record-field-children field)
                             (string-prefix? path (string-append name ".")))
                        (walk (record-field-children field) (substring path (add1 (string-length name))))]
                       [else #f])))))
      (let ([root (interface-reference-root interfaces reference)])
        (and root
             (let ([requested (map string->symbol
                                   (string-split (substring (symbol->string reference)
                                                            (add1 (string-length (symbol->string root)))) "."))])
               (define (mentioned? fields requirements [prefix '()])
                 (or (for*/or ([requirement (in-list requirements)]
                               [path (in-list (requirement-entry-references (record-requirement-expression requirement)))])
                       (define full (append prefix path))
                       (and (<= (length requested) (length full))
                            (equal? requested (take full (length requested)))))
                     (for/or ([field (in-list fields)] #:when (record-field-children field))
                       (mentioned? (record-field-children field) (record-field-requirements field)
                                   (append prefix (field-path field))))))
               (define interface (hash-ref interfaces root))
               (and (mentioned? (record-interface-fields interface) (record-interface-requirements interface))
                    (record-field (string->symbol (string-join (map symbol->string requested) "."))
                                  #f #t #f #f '())))))))

(define (combine-interface-guards outer inner)
  (cond [(not outer) inner]
        [(not inner) outer]
        [else `(binary and (,outer ,inner))]))

(define (interface-branch-guards conditions)
  (define previous #f)
  (for/list ([condition (in-list conditions)])
    (define guard
      (combine-interface-guards (and previous `(unary not (,previous))) condition))
    (when condition
      (set! previous (if previous `(binary or (,previous ,condition)) condition)))
    guard))

(define (declaration-fields parts [guard #f])
  (append*
   (for/list ([part (in-list parts)])
     (case (car part)
       [(interface-field)
        (list (record-field (cadr part) (caddr part) (cadddr part)
                            (and (list-ref part 4) (declaration-fields (list-ref part 4)))
                            guard
                            (if (list-ref part 4) (declaration-requirements (list-ref part 4)) '())))]
       [(interface-if)
        (define branches (cadr part))
        (append*
         (for/list ([branch (in-list branches)]
                    [condition (in-list (interface-branch-guards (map cadr branches)))])
           (declaration-fields (caddr branch) (combine-interface-guards guard condition))))]
       [else '()]))))

(define (declaration-requirements parts [guard #f])
  (append*
   (for/list ([part (in-list parts)])
     (case (car part)
       [(interface-requirement) (list (record-requirement (cadr part) guard))]
       [(interface-for-each) (list (record-requirement part guard))]
       [(interface-if)
        (define branches (cadr part))
        (append*
         (for/list ([branch (in-list branches)]
                    [condition (in-list (interface-branch-guards (map cadr branches)))])
           (declaration-requirements (caddr branch) (combine-interface-guards guard condition))))]
       [else '()]))))

;; Resolution permits forward references.
(define (resolve-record-interfaces declarations
                                   [fail (lambda (_name message)
                                           (error 'resolve-record-interfaces "~a" message))])
  (define resolved (make-hasheq))
  (define active (make-hasheq))
  (define (visit name [requestor name])
    (unless (hash-has-key? declarations name)
      (fail requestor (format "unknown parent interface ~a" name)))
    (when (hash-ref active name #f)
      (fail requestor (format "interface extension cycle through ~a" name)))
    (hash-ref resolved name
              (lambda ()
                (hash-set! active name #t)
                (define parts (hash-ref declarations name))
                (define own (declaration-fields parts))
                (define own-names (map record-field-name own))
                (define inherited '())
                (define requirements (declaration-requirements parts))
                (for ([part (in-list parts)] #:when (eq? (car part) 'extends))
                  (define parent (visit (cadr part) name))
                  (set! requirements (append (record-interface-requirements parent) requirements))
                  (for ([field (in-list (record-interface-fields parent))]
                        #:unless (memq (record-field-name field) own-names))
                    (define existing
                      (findf (lambda (earlier)
                               (eq? (record-field-name earlier) (record-field-name field)))
                             inherited))
                    (cond
                      [(not existing)
                       (set! inherited (append inherited (list field)))]
                      [(not (equal? existing field))
                       (fail name
                             (format "conflicting inherited field ~a in ~a; declare it explicitly"
                                     (record-field-name field) name))])))
                (define result
                  (record-interface (symbol->string name) (append inherited own)
                                    (remove-duplicates requirements)))
                (hash-remove! active name)
                (hash-set! resolved name result)
                result)))
  (for ([name (in-list (sort (hash-keys declarations) string<?
                             #:key symbol->string))])
    (visit name))
  resolved)

(define absent (gensym 'absent))
(define unknown-path (gensym 'unknown-path))
(define (field-path field)
  (map string->symbol (string-split (symbol->string (record-field-name field)) ".")))
(define (path-value record path)
  (cond [(null? path) record]
        [(or (memq record '(unknown undetermined)) (eq? record no-constant)) unknown-path]
        [else
         (define child (value-field record (car path) absent))
         (if (eq? child absent) absent (path-value child (cdr path)))]))

;; Unlike a Boolean test, a collection may contain known and unknown items.
(define (interface-value expression record)
  (define (known value)
    (cond [(memq value '(undetermined not-a-record)) no-constant]
          [(uncertain-value? value)
           (uncertain-value (known (plain-value value)) (known (uncertain-value-uncertainty value)))]
          [(hash? value) (for/hasheq ([(name part) (in-hash value)]) (values name (known part)))]
          [(list? value) (map known value)]
          [else value]))
  (define (evaluate expression)
    (match expression
      [`(typed-default ,_ (,value)) (evaluate value)]
      [`(list ,parts) (map evaluate parts)]
      [`(fields ,entries)
       (for/hasheq ([entry (in-list entries)]) (values (car entry) (evaluate (cadr entry))))]
      [`(uncertain ,base ,description) (uncertain-value (evaluate base) (evaluate description))]
      [_ (constant-value expression (lambda (name) (known (hash-ref record name no-constant))))]))
  (evaluate expression))

(define (iteration-template body)
  (if (record-interface? body) body
      (record-interface "list item" (declaration-fields body) (declaration-requirements body))))

(define (expression-location expression record)
  (match expression
    [`(result ,name) (list name)]
    [`(field-ref ,name ,receiver)
     (define parent (expression-location receiver record))
     (and parent (append parent (list name)))]
    [`(dot-select (,receiver ,selector))
     (define parent (expression-location receiver record))
     (define container (plain-value (interface-value receiver record)))
     (define key (match selector
                   [`(result ,name) (if (hash? container) name (interface-value selector record))]
                   [_ (interface-value selector record)]))
     (and parent (or (and (hash? container) (symbol? key))
                     (and (list? container) (exact-positive-integer? key)
                          (<= key (length container))))
          (append parent (list key)))]
    [_ #f]))

(define (and-status first second)
  (cond [(or (eq? first #f) (eq? second #f)) #f]
        [(and (eq? first #t) (eq? second #t)) #t]
        [else 'unknown]))

(define (interface-guard-value expression record)
  (define value (if expression (interface-value expression record) #t))
  (if (boolean? value) value 'unknown))

(define (unknown-default? expression)
  (match expression
    [`(literal unknown) #t]
    [`(uncertain ,base ,_) (unknown-default? base)]
    [`(typed-default ,_ (,value)) (unknown-default? value)]
    [_ #f]))

(define (record-field-kind field record [evaluate-default #f])
  (define default (record-field-default field))
  (match default
    [`(typed-default ,kind ,_) kind]
    [_
     (and default (not (unknown-default? default))
          (or (value-kind (constant-value default (lambda (_) no-constant) #t))
              (value-kind (if evaluate-default (evaluate-default default)
                              (interface-value default record)))
              'undetermined))]))

;; A permission comes from the resolved declaration, including its guard.
(define (unknown-permission fields path record evaluate)
  (for/fold ([permission #f]) ([field (in-list fields)])
    (define own-path (field-path field))
    (define active (if (record-field-guard field)
                       (evaluate (record-field-guard field) record) #t))
    (define found
      (cond [(equal? own-path path)
             (and (unknown-default? (record-field-default field)) active)]
            [(and (record-field-children field) (< (length own-path) (length path))
                  (equal? own-path (take path (length own-path))))
             (define child (path-value record own-path))
             (and (hash? child)
                  (and-status active
                              (unknown-permission (record-field-children field)
                                                  (drop path (length own-path)) child evaluate)))]
            [else #f]))
    (cond [(or (eq? permission #t) (eq? found #t)) #t]
          [(or (eq? permission 'unknown) (eq? found 'unknown)) 'unknown]
          [else #f])))

(define (required-value-gaps fields expression record evaluate)
  (define invalid '())
  (define pending '())
  (for ([reference (in-list (requirement-references expression))])
    ;; A known record's count is an ordinary field. If the receiver of
    ;; .count is unknown, check its declaration instead of its derived size.
    (define path
      (or (for/or ([part (in-list reference)] [position (in-naturals)])
            (and (positive? position) (eq? part 'count)
                 (let* ([parent (take reference position)]
                        [value (plain-value (path-value record parent))])
                   (and (or (memq value '(unknown undetermined)) (eq? value no-constant))
                        parent))))
          reference))
    (define value (plain-value (path-value record path)))
    (define permission (unknown-permission fields path record evaluate))
    (cond [(and (eq? value 'unknown) (eq? permission #f))
           (set! invalid (cons path invalid))]
          [(and (not (eq? permission #t))
                (or (eq? value unknown-path) (eq? value 'undetermined)
                    (eq? value no-constant) (and (eq? value 'unknown) (eq? permission 'unknown))))
           (set! pending (cons path pending))]))
  (values (reverse invalid) (reverse pending)))

(define (interface-field-gaps interface record [evaluate-guard interface-guard-value]
                              [evaluate-default #f])
  (unless (record-interface? interface)
    (raise-argument-error 'missing-interface-fields "record-interface?" interface))
  (define missing '())
  (define pending '())
  (define unknown '())
  (define wrong-kind '())
  (define (walk fields value [prefix ""] [outer #t])
    (for ([field (in-list fields)])
       (define name (string-append prefix (symbol->string (record-field-name field))))
       (define found (path-value value (field-path field)))
       (define own (if (record-field-guard field)
                       (evaluate-guard (record-field-guard field) value) #t))
       (define status (cond [(or (eq? own #f) (eq? outer #f)) #f]
                            [(and (eq? own #t) (eq? outer #t)) #t]
                            [else 'unknown]))
       (define (gap)
         (if (eq? status #t)
             (set! missing (cons (string->symbol name) missing))
             (set! pending (cons (string->symbol name) pending))))
       (unless (eq? status #f)
         (cond [(eq? found unknown-path)
                (when (or (record-field-required? field) (record-field-children field))
                  (set! pending (cons (string->symbol name) pending)))]
               [(eq? found absent) (when (record-field-required? field) (gap))]
               [(and (record-field-required? field)
                     (not (unknown-default? (record-field-default field)))
                     (eq? (plain-value found) 'unknown))
                (if (eq? status #t)
                    (set! unknown (cons (string->symbol name) unknown))
                    (set! pending (cons (string->symbol name) pending)))]
               [(and (record-field-required? field)
                     (not (unknown-default? (record-field-default field)))
                     (or (eq? (plain-value found) 'undetermined) (eq? found no-constant)))
                (set! pending (cons (string->symbol name) pending))]
               [(and (record-field-kind field value evaluate-default)
                     (not (eq? (plain-value found) 'unknown)))
                (define kind (record-field-kind field value evaluate-default))
                (cond [(or (eq? kind 'undetermined) (eq? (plain-value found) 'undetermined)
                           (eq? found no-constant))
                       (set! pending (cons (string->symbol name) pending))]
                      [(not (eq? (value-kind found) kind))
                       (if (eq? status #t)
                           (set! wrong-kind (cons (string->symbol name) wrong-kind))
                           (set! pending (cons (string->symbol name) pending)))])]
               [(record-field-children field)
                (cond [(memq found '(unknown undetermined))
                       (set! pending (cons (string->symbol name) pending))]
                      [(hash? found)
                       (walk (record-field-children field) found (string-append name ".") status)]
                      [else (gap)])]))))
  (walk (record-interface-fields interface) record)
  (values (reverse missing) (reverse pending) (reverse unknown) (reverse wrong-kind)))

(define (missing-interface-fields interface record [evaluate-guard interface-guard-value]
                                  [evaluate-default #f])
  (define-values (missing _pending _unknown _kind)
    (interface-field-gaps interface record evaluate-guard evaluate-default))
  missing)

(define (undetermined-interface-fields interface record [evaluate-guard interface-guard-value]
                                       [evaluate-default #f])
  (define-values (_missing pending _unknown _kind)
    (interface-field-gaps interface record evaluate-guard evaluate-default))
  pending)

(define (unknown-interface-fields interface record [evaluate-guard interface-guard-value]
                                  [evaluate-default #f])
  (define-values (_missing _pending unknown _kind)
    (interface-field-gaps interface record evaluate-guard evaluate-default))
  unknown)

(define (wrong-kind-interface-fields interface record [evaluate-guard interface-guard-value]
                                     [evaluate-default #f])
  (define-values (_missing _pending _unknown wrong-kind)
    (interface-field-gaps interface record evaluate-guard evaluate-default))
  wrong-kind)

(define (interface-requirement-results interface record [evaluate interface-guard-value])
  (define results '())
  (define locations (make-parameter (hasheq)))
  (define (locate prefix path)
    (if (and (pair? path) (hash-has-key? (locations) (car path)))
        (append (hash-ref (locations) (car path)) (cdr path))
        (append prefix path)))
  (define (path-label path)
    (string->symbol
     (string-join (map (lambda (part) (if (number? part) (format "[~a]" part)
                                        (symbol->string part))) path) ".")))
  (define (add prefix expression outcome [missing '()])
    (set! results (cons (requirement-result prefix expression outcome missing) results)))
  (define (item-location expression value prefix index)
    (define references (requirement-references expression))
    (define location (expression-location expression value))
    (append (locate prefix (or location (and (= (length references) 1) (car references)) '(items)))
            (list index)))
  (define (relocate name binder location)
    (define text (symbol->string name))
    (define root (symbol->string binder))
    (define shown
      (string-join (map (lambda (part) (if (number? part) (format "[~a]" part)
                                         (symbol->string part))) location) "."))
    (string->symbol (if (or (string=? text root) (string-prefix? text (string-append root ".")))
                       (string-append shown (substring text (string-length root))) text)))
  (define (walk fields requirements value [prefix '()] [outer #t])
    (for ([requirement (in-list requirements)])
      (define guard (record-requirement-guard requirement))
      (define active (and-status outer (if guard (evaluate guard value) #t)))
      (unless (eq? active #f)
        (define expression (record-requirement-expression requirement))
        (cond
          [(and (pair? expression) (eq? (car expression) 'interface-for-each))
           (match-define `(interface-for-each ,binder ,collection ,body) expression)
           (define items (plain-value (interface-value collection value)))
           (define template (iteration-template body))
           (define-values (invalid _pending-values)
             (required-value-gaps fields expression value evaluate))
           (define missing-collection
             (for/list ([path (in-list (requirement-references collection))]
                        #:when (eq? (path-value value path) absent))
               (path-label (locate prefix path))))
           (cond
             [(pair? missing-collection)
              (add prefix expression (if (eq? active #t) 'violated 'undetermined) missing-collection)]
             [(pair? invalid) (add prefix expression (if (eq? active #t) 'violated 'undetermined))]
             [(unresolved? items) (add prefix expression 'undetermined)]
             [(not (list? items))
              (add prefix expression (if (eq? active #t) 'violated 'undetermined))]
             [else
              (when (null? items) (add prefix expression 'satisfied))
              (for ([item (in-list items)] [index (in-naturals 1)])
                (define local (hash-set value binder item))
                (define location (item-location collection value prefix index))
                (define missing (missing-interface-fields template local evaluate))
                (define pending (undetermined-interface-fields template local evaluate))
                (define unknown (unknown-interface-fields template local evaluate))
                (define wrong-kind (wrong-kind-interface-fields template local evaluate))
                (unless (null? missing)
                  (add location expression (if (eq? active #t) 'violated 'undetermined)
                       (map (lambda (name) (relocate name binder location)) missing)))
                (unless (null? pending) (add location expression 'undetermined))
                (unless (and (null? unknown) (null? wrong-kind))
                  (add location expression (if (eq? active #t) 'violated 'undetermined)))
                (parameterize ([locations (hash-set (locations) binder location)])
                  (walk (record-interface-fields template) (record-interface-requirements template)
                        local location active)))])]
          [else
           (define-values (invalid pending-values)
             (required-value-gaps fields expression value evaluate))
           (define missing
             (for/list ([path (in-list (requirement-references expression))]
                        #:when (eq? (path-value value path) absent))
               (path-label (locate prefix path))))
           (define outcome
             (cond [(pair? missing) (if (eq? active #t) 'violated 'undetermined)]
                   [(pair? invalid) (if (eq? active #t) 'violated 'undetermined)]
                   [else
                    (define answer (evaluate expression value))
                    (cond [(and (eq? answer #f) (eq? active #t)) 'violated]
                          [(and (eq? answer #t) (null? pending-values)) 'satisfied]
                          [else 'undetermined])]))
           (add prefix expression outcome missing)])))
    (for ([field (in-list fields)] #:when (record-field-children field))
      (define found (path-value value (field-path field)))
      (define guard (record-field-guard field))
      (define active (and-status outer (if guard (evaluate guard value) #t)))
      (when (and (hash? found) (not (eq? active #f)))
        (walk (record-field-children field) (record-field-requirements field) found
              (locate prefix (field-path field)) active))))
  (walk (record-interface-fields interface) (record-interface-requirements interface) record)
  (reverse results))

(define (complete-interface-record interface overrides evaluate-default
                                   [evaluate-guard interface-guard-value])
  (unless (record-interface? interface)
    (raise-argument-error 'interface-record "record-interface?" interface))
  (unless (hash? overrides)
    (raise-argument-error 'interface-record "hash?" overrides))
  (define (put-path record path value)
    (define name (car path))
    (if (null? (cdr path))
        (let ([earlier (hash-ref record name #f)])
          (hash-set record name
                    (if (and (hash? earlier) (hash? value))
                        (merge-records earlier value)
                        value)))
        (hash-set record name
                  (put-path (let ([current (hash-ref record name #f)])
                              (if (hash? current) current (hasheq)))
                            (cdr path) value))))
  (define (merge-records old changes)
    (for/fold ([result old]) ([(name value) (in-hash changes)])
      (define earlier (hash-ref result name #f))
      ;; A supplied value replaces a default; kind checks follow completion.
      (hash-set result name
                (if (and (hash? earlier) (hash? value))
                    (merge-records earlier value)
                    value))))
  (define (active? field values)
    (define guard (record-field-guard field))
    (if guard (eq? (evaluate-guard guard values) #t) #t))
  (define (defaults-for fields [values (hasheq)])
    (for/fold ([record (hasheq)])
              ([field (in-list fields)] #:when (active? field values))
      (cond [(record-field-default field)
             (let check ([value values] [path (field-path field)])
               (when (pair? path)
                 (when (and (eq? (car path) 'count) (list? (plain-value value)))
                   (error 'interface-record "the list property .count is read only; use == for an exact count"))
                 (check (value-field value (car path) absent) (cdr path))))
             (put-path record (field-path field)
                       (evaluate-default (record-field-default field)))]
            [(and (record-field-children field) (record-field-required? field))
             (define existing (path-value values (field-path field)))
             (define nested (defaults-for (record-field-children field)
                                          (if (hash? existing) existing (hasheq))))
             (if (zero? (hash-count nested)) record
                 (put-path record (field-path field) nested))]
            [else record])))
  (define (complete fields requirements values)
    (define combined
      (let loop ([current values])
        (define next (merge-records (defaults-for fields current) current))
        (if (equal? next current) current (loop next))))
    (define nested
      (for/fold ([record combined])
                ([field (in-list fields)]
                 #:when (and (record-field-children field) (active? field combined)))
        (define found (path-value record (field-path field)))
        (cond [(eq? found absent) record]
              [(not (hash? found))
               (error 'interface-record "nested field ~a needs a record" (record-field-name field))]
              [else (put-path record (field-path field)
                              (complete (record-field-children field)
                                        (record-field-requirements field) found))])))
    (for/fold ([record nested]) ([requirement (in-list requirements)])
      (define expression (record-requirement-expression requirement))
      (define guard (record-requirement-guard requirement))
      (cond
        [(and (pair? expression) (eq? (car expression) 'interface-for-each)
              (or (not guard) (eq? (evaluate-guard guard record) #t)))
         (match-define `(interface-for-each ,binder ,collection ,body) expression)
         (define original (interface-value collection record))
         (define items (plain-value original))
         (define template (iteration-template body))
         (define (replace value path replacement)
           (if (null? path) replacement
               (let* ([name (car path)]
                      [plain (plain-value value)]
                      [child (if (list? plain) (list-ref plain (sub1 name))
                                 (hash-ref plain name))]
                      [updated (replace child (cdr path) replacement)]
                      [result (if (list? plain) (list-set plain (sub1 name) updated)
                                  (hash-set plain name updated))])
                 (if (uncertain-value? value)
                     (uncertain-value result (uncertain-value-uncertainty value)) result))))
         (define path (expression-location collection record))
         (if (and path (list? items))
             (let ([completed-items
              (for/list ([item (in-list items)])
                (define local (hash-set record binder item))
                (define completed
                  (complete-interface-record
                   template local
                   (lambda (default)
                     (define answer (interface-value default local))
                     (if (eq? answer no-constant) (evaluate-default default) answer))
                   evaluate-guard))
                (hash-ref completed binder item))])
               (replace record path
                        (if (uncertain-value? original)
                            (uncertain-value completed-items (uncertain-value-uncertainty original))
                            completed-items)))
             record)]
        [else record])))
  (let loop ([current overrides])
    (define next (complete (record-interface-fields interface)
                           (record-interface-requirements interface) current))
    (if (equal? next current) current (loop next))))

(define (interface-record interface overrides evaluate-default
                          [evaluate-guard interface-guard-value])
  (define result (complete-interface-record interface overrides evaluate-default evaluate-guard))
  (define requirements (interface-requirement-results interface result evaluate-guard))
  (define missing
    (remove-duplicates
     (append (missing-interface-fields interface result evaluate-guard evaluate-default)
             (append* (map requirement-result-missing
                           (filter (lambda (check) (eq? (requirement-result-outcome check) 'violated)) requirements))))))
  (unless (null? missing)
    (error 'interface-record "~a is missing field~a ~a"
           (record-interface-name interface)
           (if (= (length missing) 1) "" "s")
           (string-join (map symbol->string missing) ", ")))
  (define unknown (unknown-interface-fields interface result evaluate-guard evaluate-default))
  (unless (null? unknown)
    (error 'interface-record "~a does not allow unknown for field~a ~a; declare a default of unknown to permit it"
           (record-interface-name interface) (if (= (length unknown) 1) "" "s")
           (string-join (map symbol->string unknown) ", ")))
  (define wrong-kind (wrong-kind-interface-fields interface result evaluate-guard evaluate-default))
  (unless (null? wrong-kind)
    (error 'interface-record "~a has a value of the wrong kind for field~a ~a"
           (record-interface-name interface) (if (= (length wrong-kind) 1) "" "s")
           (string-join (map symbol->string wrong-kind) ", ")))
  (define pending (undetermined-interface-fields interface result evaluate-guard evaluate-default))
  (unless (null? pending)
    (error 'interface-record "~a has undetermined conditional requirements: ~a"
           (record-interface-name interface)
           (string-join (map symbol->string pending) ", ")))
  (for ([check (in-list requirements)])
    (define location
      (if (null? (requirement-result-scope check)) ""
          (string-append " at "
                         (string-join
                          (map (lambda (part) (if (number? part) (format "[~a]" part)
                                                 (symbol->string part)))
                               (requirement-result-scope check)) "."))))
    (case (requirement-result-outcome check)
      [(violated)
       (error 'interface-record "~a does not satisfy value requirement ~s~a"
              (record-interface-name interface) (requirement-result-expression check) location)]
      [(undetermined)
       (error 'interface-record "~a has an undetermined value requirement ~s~a"
              (record-interface-name interface) (requirement-result-expression check) location)]))
  result)
