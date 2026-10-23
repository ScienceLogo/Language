#lang racket/base

(require file/sha1
         racket/file
         racket/list
         racket/match
         racket/path
         racket/port
         racket/string
         racket/system
         syntax/readerr
         "../normalize.rkt"
         "source-offsets.rkt"
         "expression-groups.rkt"
         "record-interfaces.rkt"
         "value-kinds.rkt")

(provide sciencelogo-read
         sciencelogo-read-syntax
         parse-sciencelogo-file
         parse-sciencelogo-tree-file
         node->datum
         ungroup-node
         state-call-location-syntax
         (struct-out token)
         (struct-out node))

(struct token (kind value line column position source) #:transparent)
(struct node (kind value children at) #:transparent)

;; This is a temporary view for structural checks. The source tree retains
;; every group, including redundant and nested parentheses.
(define (ungroup-node value)
  (if (eq? (node-kind value) 'group)
      (ungroup-node (car (node-children value))) value))

(define (map-grouped-node value transform)
  (if (eq? (node-kind value) 'group)
      (struct-copy node value
                   [children (list (map-grouped-node (car (node-children value)) transform))])
      (transform value)))

(define (read-error source at message)
  (raise-read-error message (token-source at) (token-line at) (token-column at)
                    (token-position at) 1))

(define (lex text source)
  (define in (open-input-string text source))
  (define offset (make-character-offset text in))
  (port-count-lines! in)
  (define (at kind value)
    (define-values (line column _position) (port-next-location in))
    (token kind value line column (add1 (offset)) source))
  (define (skip-line)
    (let loop ()
      (define c (read-char in))
      (unless (or (eof-object? c) (char=? c #\newline)) (loop))))
  (define (skip-block start)
    (let loop ([depth 1])
      (define c (read-char in))
      (cond
        [(eof-object? c) (read-error source start "unclosed #| comment")]
        [(and (char=? c #\#) (eqv? (peek-char in) #\|))
         (read-char in)
         (loop (add1 depth))]
        [(and (char=? c #\|) (eqv? (peek-char in) #\#))
         (read-char in)
         (unless (= depth 1) (loop (sub1 depth)))]
        [else (loop depth)])))
  (define (word-char? c)
    (and (char? c)
         (not (char-whitespace? c))
         (not (memv c '(#\[ #\] #\( #\) #\; #\" #\#)))))
  (let loop ([backward '()])
    (define start (at 'pending #f))
    (define c (peek-char in))
    (cond
      [(eof-object? c) (reverse (cons (at 'eof #f) backward))]
      [(char-whitespace? c) (read-char in) (loop backward)]
      [(char=? c #\;) (skip-line) (loop backward)]
      [(char=? c #\#)
       (read-char in)
       (if (eqv? (peek-char in) #\|)
           (begin (read-char in) (skip-block start) (loop backward))
           (read-error source start "expected #| to start a block comment"))]
      [(char=? c #\[)
       (read-char in)
       (loop (cons (struct-copy token start [kind 'open] [value "["]) backward))]
      [(char=? c #\])
       (read-char in)
       (loop (cons (struct-copy token start [kind 'close] [value "]"]) backward))]
      [(char=? c #\()
       (read-char in)
       (loop (cons (struct-copy token start [kind 'left-paren] [value "("]) backward))]
      [(char=? c #\))
       (read-char in)
       (loop (cons (struct-copy token start [kind 'right-paren] [value ")"]) backward))]
      [(char=? c #\")
       (define value (read in))
       (loop (cons (struct-copy token start [kind 'string] [value value]) backward))]
      [else
       (define text (open-output-string))
       (let word-loop ()
         (when (word-char? (peek-char in))
           (write-char (read-char in) text)
           (word-loop)))
       (define value (get-output-string text))
       (loop (cons (struct-copy token start [kind 'word] [value value]) backward))])))

(define (parse-tree in source [expected-kind #f] [expand-local? #t])
  ;; Normalize spelling before the compact grammar sees the source. Keep
  ;; original locations even when a verbose access changes word order.
  (port-count-lines! in)
  (define-values (line column position) (port-next-location in))
  (define normalized
    (normalize-source (port->string in) #:source source
                      #:line (or line 1) #:column (or column 0)
                      #:position (or position 1)))
  (define tokens
    (list->vector
     (for/list ([found (in-list (lex (normalized-source-text normalized) source))])
       (define origin (normalized-source-origin normalized (token-position found)))
       (struct-copy token found
                    [line (source-origin-line origin)]
                    [column (source-origin-column origin)]
                    [position (source-origin-position origin)]
                    [source (source-origin-source origin)]))))
  (define index 0)
  (define commands '("to" "do" "stage" "end" "print" "output" "include" "implements" "must" "workflow" "interface" "performer" "resource" "hypothesis" "assumption" "conclusion" "repeat" "for" "while" "if" "else" "set" "about"))
  (define reserved
    (append commands '("as" "at" "from" "with" "into" "state" "import" "workflow" "library"
                       "interface" "version" "require" "affects" "provide" "by"
                       "each" "in" "until" "range" "step" "true" "false"
                       "unknown" "=" "==" "+=" "!=" "<" "<=" ">" ">="
                       "+" "-" "*" "/" "and" "or" "not" "xor" "of" "but" "implement" "is"
                       "extends" "hypotheses" "assumptions" "conclusions" "u")))
  (define (current) (vector-ref tokens index))
  (define (advance!)
    (define result (current))
    (set! index (add1 index))
    result)
  (define (expect kind description)
    (define found (current))
    (unless (eq? (token-kind found) kind)
      (read-error source found (format "expected ~a" description)))
    (advance!))
  (define (expect-word expected)
    (define found (expect 'word expected))
    (unless (string=? (token-value found) expected)
      (read-error source found (format "expected ~a" expected)))
    found)
  (define (named-word description [allowed '()])
    (define found (expect 'word description))
    (define text (token-value found))
    (when (or (and (member text reserved) (not (member text allowed)))
              (and (positive? (string-length text))
                   (char=? (string-ref text 0) #\:)))
      (read-error source found (format "expected ~a" description)))
    (string->symbol text))
  (define comparisons '("==" "!=" "<" "<=" ">" ">=" "in" "is"))
  (define (valid-inline-interface-name? name)
    (and (not (string=? name ""))
         (not (regexp-match? #px"[\\s\\[\\]();\"#]" name))
         (not (regexp-match? #px"^:" name))
         (not (regexp-match? #rx"[.]" name))
         (not (regexp-match? #px"^[+-]?[0-9]" name))
         (not (member name reserved))))
  (define (identifier-name description [qualified? #f])
    (define at (current))
    (define name (token-value (expect 'word description)))
    (unless (andmap valid-inline-interface-name?
                    (if qualified? (string-split name "." #:trim? #f) (list name)))
      (read-error source at (format "expected ~a" description)))
    name)
  (define (operator-precedence name)
    (cond [(member name '("*" "/")) 60]
          [(member name '("+" "-")) 50]
          [(member name comparisons) 40]
          [(string=? name "and") 30]
          [(string=? name "xor") 20]
          [(string=? name "or") 10]
          [else #f]))
  (define (parse-value [minimum 0] [stop-word #f])
    (define left (parse-atom stop-word))
    (let loop ([left left])
      (define found (current))
      (define operator
        (and (eq? (token-kind found) 'word)
             (not (and stop-word (string=? (token-value found) stop-word)))
             (operator-precedence (token-value found))))
      (if (and operator (>= operator minimum))
          (begin
            (when (and (= operator 40) (memq (node-kind left) '(compare kind-test)))
              (read-error source found "comparison cannot be chained; use and"))
            (advance!)
            (if (string=? (token-value found) "is")
                (let ([kind (named-word "a value kind or interface name after is")])
                  (loop (node 'kind-test kind (list left) found)))
                (let ([right (parse-value (add1 operator) stop-word)])
                  (loop (node (if (= operator 40) 'compare 'binary)
                              (string->symbol (token-value found))
                              (list left right) found)))))
          left)))
  (define (object-value value message)
    (map-grouped-node
     value
     (lambda (raw)
       (cond [(eq? (node-kind raw) 'fields) raw]
             [(and (eq? (node-kind raw) 'list) (null? (node-children raw)))
              (struct-copy node raw [kind 'fields])]
             [else (read-error source (node-at value) message)]))))
  (define (dotted-value found text)
    (define input? (string-prefix? text ":"))
    (define parts (string-split (if input? (substring text 1) text)
                                "." #:trim? #f))
    (when (or (string=? (car parts) "")
              (member "" (drop-right parts 1)))
      (read-error source found "empty part in dotted path"))
    (define root
      (node (if input? 'parameter 'result)
            (string->symbol (car parts))
            '() found))
    (define (bracket receiver at)
      (define selector (parse-atom #f #f))
      (case (node-kind selector)
        [(fields) (node 'dot-update #f (list receiver selector) at)]
        [(list)
         (if (null? (node-children selector))
             (node 'dot-update #f
                   (list receiver (struct-copy node selector [kind 'fields])) at)
             (node 'dot-select #f (cons receiver (node-children selector)) at))]
        [else (read-error source at "expected [ ... ] after dot")]))
    (define (fields receiver tail at)
      (for/fold ([value receiver]) ([part (in-list tail)]
                                    #:unless (string=? part ""))
        (node 'field-ref (string->symbol part) (list value) at)))
    (define initial (fields root (cdr parts) found))
    (define after-bracket
      (if (string=? (last parts) "") (bracket initial found) initial))
    (let loop ([value after-bracket])
      (define next (current))
      (if (and (eq? (token-kind next) 'word)
               (string-prefix? (token-value next) "."))
          (let* ([text (token-value (advance!))]
                 [tail (cdr (string-split text "." #:trim? #f))])
            (when (or (null? tail) (member "" (drop-right tail 1)))
              (read-error source next "empty part in dotted path"))
            (define extended (fields value tail next))
            (loop (if (string=? (last tail) "")
                      (bracket extended next)
                      extended)))
          value)))
  (define (normalize-fields fields)
    (define (insert entries parts value at)
      (define name (string->symbol (car parts)))
      (define existing (findf (lambda (entry) (eq? (node-value entry) name)) entries))
      (define replacement
        (cond
          [(null? (cdr parts))
           (when existing
             (read-error source at (format "duplicate field ~a" name)))
           (node 'field-entry name (list value) at)]
          [else
           (define old-value (and existing (car (node-children existing))))
           (when (and old-value (not (eq? (node-kind (ungroup-node old-value)) 'fields)))
             (read-error source at (format "field ~a is already a value" name)))
           (define nested
             (map-grouped-node
              (or old-value (node 'fields #f '() at))
              (lambda (raw)
                (struct-copy node raw
                             [children (insert (node-children raw) (cdr parts) value at)]))))
           (node 'field-entry name (list nested) at)]))
      (if existing
          (for/list ([entry (in-list entries)])
            (if (eq? (node-value entry) name) replacement entry))
          (append entries (list replacement))))
    (struct-copy node fields
                 [children
                  (for/fold ([entries '()]) ([entry (in-list (node-children fields))])
                    (define parts
                      (string-split (symbol->string (node-value entry)) "."
                                    #:trim? #f))
                    (when (member "" parts)
                      (read-error source (node-at entry) "empty part in field path"))
                    (insert entries parts (car (node-children entry))
                            (node-at entry)))]))
  (define (postfix-value base)
    (let loop ([value base])
      (define at (current))
      (cond
        [(and (eq? (token-kind at) 'word)
              (string=? (token-value at) "u"))
         (when (eq? (node-kind (ungroup-node value)) 'uncertain)
           (read-error source at "a value can have only one u description"))
         (advance!)
         (define raw (parse-atom #f #f))
         (define fields (object-value raw "u needs named fields or []"))
         (for ([entry (in-list (node-children (ungroup-node fields)))])
           (unless (memq (node-value entry) '(declared omitted))
             (read-error source (node-at entry)
                         "u fields must be declared or omitted"))
           (define collection (ungroup-node (first (node-children entry))))
           (unless (or (eq? (node-kind collection) 'fields)
                       (and (eq? (node-kind collection) 'list)
                            (null? (node-children collection))))
             (read-error source (node-at entry)
                         (format "u ~a needs named entries or []"
                                 (node-value entry))))
           (when (eq? (node-kind collection) 'fields)
             (for ([source-entry (in-list (node-children collection))])
               (define source-fields (ungroup-node (first (node-children source-entry))))
               (unless (or (eq? (node-kind source-fields) 'fields)
                           (and (eq? (node-kind source-fields) 'list)
                                (null? (node-children source-fields))))
                 (read-error source (node-at source-entry)
                             "a u source needs named fields or []")))))
         (loop (node 'uncertain #f (list value fields) at))]
        [(and (eq? (token-kind at) 'word)
              (string-prefix? (token-value at) "."))
          (let* ([text (token-value (advance!))]
                 [parts (cdr (string-split text "." #:trim? #f))])
            (when (or (null? parts) (member "" (drop-right parts 1)))
              (read-error source at "empty part in dotted path"))
            (define extended
              (for/fold ([receiver value]) ([part (in-list parts)]
                                            #:unless (string=? part ""))
                (node 'field-ref (string->symbol part) (list receiver) at)))
            (if (string=? (last parts) "")
                (let ([selector (parse-atom #f #f)])
                  (case (node-kind selector)
                    [(fields) (loop (node 'dot-update #f
                                          (list extended selector) at))]
                    [(list)
                     (loop (if (null? (node-children selector))
                               (node 'dot-update #f
                                     (list extended
                                           (struct-copy node selector [kind 'fields]))
                                     at)
                               (node 'dot-select #f
                                     (cons extended (node-children selector)) at)))]
                    [else (read-error source at "expected [ ... ] after dot")]))
                (loop extended)))]
        [else value])))
  (define (parse-atom [stop-word #f] [allow-postfix? #t])
    (define found (current))
    (define raw (case (token-kind found)
      [(left-paren)
       (advance!)
       (define value (parse-value))
       (expect 'right-paren ") after grouped expression")
       (node 'group #f (list value) found)]
      [(open)
       (advance!)
       (define fields?
         (and (eq? (token-kind (current)) 'word)
              (< (add1 index) (vector-length tokens))
              (let ([next (vector-ref tokens (add1 index))])
                (and (eq? (token-kind next) 'word)
                     (string=? (token-value next) "=")))))
       (if fields?
           (normalize-fields (node 'fields #f
                 (let loop ([backward '()] [seen '()])
                   (case (token-kind (current))
                     [(close) (advance!) (reverse backward)]
                     [(eof) (read-error source (current) "expected ] after named fields")]
                     [else
                      (define field-at (current))
                      (define name
                        (named-word "a field name"
                                    '("hypotheses" "assumptions" "conclusions")))
                      (when (memq name seen)
                        (read-error source field-at
                                    (format "duplicate field ~a" name)))
                      (expect-word "=")
                      (define value (parse-value))
                      (loop (cons (node 'field-entry name (list value) field-at)
                                  backward)
                            (cons name seen))]))
                 found))
           (node 'list #f
                 (let loop ([backward '()])
                   (case (token-kind (current))
                     [(close) (advance!) (reverse backward)]
                     [(eof) (read-error source (current) "expected ] after list values")]
                     [else (loop (cons (parse-value) backward))]))
                 found))]
      [(string)
       (advance!)
       (node 'literal (token-value found) '() found)]
      [(word)
       (define text (token-value found))
       (advance!)
       (cond
         [(string=? text "not")
          (node 'unary 'not (list (parse-value 40 stop-word)) found)]
         [(string=? text "-")
          (node 'unary '- (list (parse-value 70 stop-word)) found)]
         [(string=? text "range")
          (define start (parse-value))
          (expect-word "to")
          (define end (parse-value))
          (expect-word "step")
          (node 'range #f (list start end (parse-value)) found)]
         [(member text '("hypothesis" "assumption" "conclusion"))
          (define name (named-word "a proposition name"))
          (when (regexp-match? #rx"[.]" (symbol->string name))
            (read-error source found "a proposition name cannot contain a dot"))
          (node 'proposition-value (list (string->symbol text) name)
                (list (parse-proposition-object)) found)]
         [(member text '("hypotheses" "assumptions" "conclusions"))
          (node 'result (string->symbol text) '() found)]
         [(member text '("true" "false" "unknown"))
          (node 'literal (cond [(string=? text "unknown") 'unknown]
                               [else (string=? text "true")]) '() found)]
         [(regexp-match? #px"^[+-]?[0-9]+(?:[.][0-9]+)?$" text)
          (node 'literal (string->number (string-append "#e" text)) '() found)]
         [(and (> (string-length text) 1) (char=? (string-ref text 0) #\:))
          (dotted-value found text)]
         [(or (member text reserved)
              (string=? text ":"))
          (read-error source found "expected a value")]
         [else (dotted-value found text)])]
      [else (read-error source found "expected a value")]))
    (if allow-postfix? (postfix-value raw) raw))
  (define (parse-condition) (parse-value))
  (define (parse-if command in-procedure?)
    (define (branch start condition)
      (expect 'open "[ after if condition or else")
      (node 'branch condition (parse-body #f in-procedure? #f #f) start))
    (define first (branch command (parse-condition)))
    (define more
      (let loop ([backward '()])
        (if (and (eq? (token-kind (current)) 'word)
                 (string=? (token-value (current)) "else"))
            (let ([else-at (advance!)])
              (if (and (eq? (token-kind (current)) 'word)
                       (string=? (token-value (current)) "if"))
                  (begin
                    (advance!)
                    (loop (cons (branch else-at (parse-condition)) backward)))
                  (reverse (cons (branch else-at #f) backward))))
            (reverse backward))))
    (node 'if #f (cons first more) command))
  (define (call-end?)
    (define found (current))
    (or (memq (token-kind found) '(close eof))
        (and (eq? (token-kind found) 'word)
             (member (token-value found) commands))
        (and (eq? (token-kind found) 'word)
             (< (add1 index) (vector-length tokens))
             (let ([next (vector-ref tokens (add1 index))])
               (and (eq? (token-kind next) 'word)
                    (member (token-value next) '("=" "+=")))))
        (and (eq? (token-kind found) 'word)
             (string-suffix? (token-value found) ".")
             (< (+ index 3) (vector-length tokens))
             (eq? (token-kind (vector-ref tokens (add1 index))) 'open)
             (eq? (token-kind (vector-ref tokens (+ index 2))) 'word)
             (member (token-value (vector-ref tokens (+ index 3)))
                     '("=" "+=")))))
  (define (parse-import start)
    (define url (token-value (expect 'string "a quoted Git repository URL")))
    (expect-word "at")
    (define revision (token-value (expect 'string "a quoted tag or commit")))
    (expect-word "as")
    (define alias (named-word "an import alias"))
    (when (regexp-match? #rx"[.]" (symbol->string alias))
      (read-error source start "an import alias cannot contain a dot"))
    (node 'import (list url revision alias) '() start))
  (define (parse-state-object)
    (expect-word "state")
    (object-value (parse-atom) "state needs named sets in [name = value] or []"))
  (define (parse-performer-object)
    (object-value (parse-atom) "performer needs named fields in [name = value] or []"))
  (define (parse-resource-object)
    (object-value (parse-atom) "resource needs named fields in [name = value] or []"))
  (define (parse-proposition-object)
    (define fields
      (object-value (parse-atom) "proposition needs named fields in [text = value] or []"))
    (for ([entry (in-list (node-children (ungroup-node fields)))])
      (unless (memq (node-value entry) '(text hypotheses assumptions conclusions))
        (read-error source (node-at entry)
                    "proposition fields must be text, hypotheses, assumptions, or conclusions"))
      (when (memq (node-value entry) '(hypotheses assumptions conclusions))
        (define collection (ungroup-node (first (node-children entry))))
        (unless (or (eq? (node-kind collection) 'fields)
                    (and (eq? (node-kind collection) 'list)
                         (null? (node-children collection))))
          (read-error source (node-at entry)
                      (format "proposition ~a needs named entries" (node-value entry))))))
    fields)
  (define (parse-location)
    (define at (expect 'word "a state location such as information.elapsed"))
    (define value (dotted-value at (token-value at)))
    (define (path-parts part)
      (case (node-kind part)
        [(result) (list (node-value part))]
        [(field-ref)
         (append (path-parts (car (node-children part)))
                 (list (node-value part)))]
        [(dot-select)
         (define children (node-children part))
         (unless (= (length children) 2)
           (read-error source at "state list location needs one position"))
         (define position (ungroup-node (second children)))
         (define index
           (case (node-kind position)
             [(literal)
              (unless (exact-positive-integer? (node-value position))
                (read-error source at "state list position starts at 1"))
              (node-value position)]
             [(result) (list 'index (node-value position))]
             [else (read-error source at "state list position needs a number or name")]))
         (append (path-parts (first children))
                 (list index))]
        [else (read-error source at "state location needs one field or position")]))
    (define parts (path-parts value))
    (unless (and (>= (length parts) 2)
                 (memq (car parts) '(information environment factors))
                 (andmap (lambda (part)
                           (or (exact-positive-integer? part)
                               (and (pair? part) (eq? (car part) 'index))
                               (and (symbol? part)
                                    (not (member (symbol->string part) reserved)))))
                         (cdr parts)))
      (read-error source at
                  "location must begin with information, environment, or factors and name a field"))
    (node 'location parts (list value) at))
  (define (parse-state-mappings)
    (expect 'open "[ after with")
    (let loop ([backward '()] [seen '()])
      (case (token-kind (current))
        [(close) (advance!) (reverse backward)]
        [(eof) (read-error source (current) "expected ] after input locations")]
        [else
         (define at (current))
         (define name (named-word "a function input name"))
         (when (memq name seen)
           (read-error source at (format "duplicate input mapping ~a" name)))
         (expect-word "at")
         (loop (cons (node 'state-mapping name (list (parse-location)) at) backward)
               (cons name seen))])))
  ;; Descriptions belong to their owner, rather than becoming activities in
  ;; that owner's body. Only these explicit attachment points consume about.
  (define (parse-about)
    (if (and (eq? (token-kind (current)) 'word)
             (string=? (token-value (current)) "about"))
        (let* ([at (advance!)]
               [text (token-value (expect 'string "quoted Markdown text after about"))])
          (when (and (eq? (token-kind (current)) 'word)
                     (string=? (token-value (current)) "about"))
            (read-error source (current) "only one about description is allowed per named part"))
          (list (node 'about text '() at)))
        '()))
  (define (parse-state-stage name performer command in-procedure?)
    (define entry (parse-state-object))
    (let loop ([backward (parse-about)])
      (define found (current))
      (cond
        [(eq? (token-kind found) 'eof)
         (read-error source found (format "stage ~s needs end stage with state" name))]
        [(eq? (token-kind found) 'close)
         (read-error source found (format "stage ~s needs end stage with state" name))]
        [(and (eq? (token-kind found) 'word)
              (string=? (token-value found) "end"))
         (advance!)
         (expect-word "stage")
         (expect-word "with")
         (node 'state-stage (list name entry (parse-state-object) performer)
               (reverse backward) command)]
        [else
         (loop (cons (parse-form #f in-procedure? #f #f) backward))])))
  (define (parse-body definitions-allowed? in-procedure? includes-allowed?
                      imports-allowed?)
    (let loop ([backward '()])
      (define found (current))
      (case (token-kind found)
        [(close) (advance!) (reverse backward)]
        [(eof) (read-error source found "expected ] before end of file")]
        [else (loop (cons (parse-form definitions-allowed? in-procedure?
                                     includes-allowed? imports-allowed?) backward))])))
  (define (parse-form definitions-allowed? in-procedure? includes-allowed?
                      imports-allowed?)
    (define command (current))
    (unless (eq? (token-kind command) 'word)
      (read-error source command "expected a command or an unquoted implementation target"))
    (advance!)
    (match (token-value command)
      ["to"
       (unless definitions-allowed?
         (read-error source command "to definitions belong in the investigation, not a do block"))
       (define name (named-word "a procedure name"))
       (when (regexp-match? #rx"[.]" (symbol->string name))
         (read-error source command "a procedure name cannot contain a dot"))
       (define inputs
         (let loop ([backward '()])
           (define found (current))
           (if (eq? (token-kind found) 'open)
               (reverse backward)
               (let* ([word (token-value (expect 'word "an input such as :paper"))]
                      [input (and (> (string-length word) 1)
                                  (char=? (string-ref word 0) #\:)
                                  (string->symbol (substring word 1)))])
                 (unless input
                   (read-error source found "expected an input such as :paper"))
                 (when (memq input backward)
                   (read-error source found (format "duplicate input ~a" input)))
                (when (regexp-match? #rx"[.]" word)
                  (read-error source found "an input name cannot contain a dot"))
                 (loop (cons input backward))))))
       (expect 'open "[ after procedure inputs")
       (define description (parse-about))
       (node 'to (cons name inputs)
             (append description (parse-body #f #t #f #f)) command)]
      ["about"
       (read-error source command
                   "about belongs at the start of a workflow or procedure, or immediately after a stage header")]
      ["include"
       (unless (and definitions-allowed? (not in-procedure?))
         (read-error source command "include belongs directly in a workflow or library file"))
       (node 'include (token-value (expect 'string "a quoted relative file path"))
             '() command)]
      ["import"
       (unless imports-allowed?
         (read-error source command "import belongs directly in a library or at the top of a workflow"))
       (parse-import command)]
      ["workflow"
       (read-error source command
                   (if includes-allowed?
                       "workflow title is not allowed in a library"
                       "workflow title appears only once at the top of a workflow file"))]
      ["interface"
       (unless (and definitions-allowed? (not in-procedure?))
         (read-error source command "interface belongs directly in a workflow or library"))
       (define name (identifier-name "an unquoted interface name"))
       (expect 'open "[ after the interface name")
       (define declaration (node 'interface name (parse-interface-body) command))
       declaration]
      ["performer"
       (unless (and definitions-allowed? (not in-procedure?)
                    (not includes-allowed?) (not imports-allowed?))
         (read-error source command "performer belongs directly in a workflow"))
       (define name (named-word "a performer name"))
       (when (regexp-match? #rx"[.]" (symbol->string name))
         (read-error source command "a performer name cannot contain a dot"))
       (node 'performer name (list (parse-performer-object)) command)]
      ["resource"
       (unless (and definitions-allowed? (not in-procedure?)
                    (not includes-allowed?) (not imports-allowed?))
         (read-error source command "resource belongs directly in a workflow"))
       (define name (named-word "a resource name"))
       (when (regexp-match? #rx"[.]" (symbol->string name))
         (read-error source command "a resource name cannot contain a dot"))
       (node 'resource name (list (parse-resource-object)) command)]
      [(or "hypothesis" "assumption" "conclusion")
       (unless (and definitions-allowed? (not in-procedure?)
                    (not includes-allowed?) (not imports-allowed?))
         (read-error source command "proposition belongs directly in a workflow"))
       (define name (named-word "a proposition name"))
       (when (regexp-match? #rx"[.]" (symbol->string name))
         (read-error source command "a proposition name cannot contain a dot"))
       (node 'proposition (list (string->symbol (token-value command)) name)
             (list (parse-proposition-object)) command)]
      ["implements"
       (unless (and definitions-allowed? (not in-procedure?)
                    (not includes-allowed?) (not imports-allowed?))
         (read-error source command "implements belongs directly in an investigation"))
       (define path (token-value (expect 'string "a quoted interface file path")))
       (when (or (string=? path "")
                 (not (relative-path? (string->path path))))
         (read-error source command "interface file path must be relative"))
       (expect-word "as")
       (define alias (named-word "an interface alias"))
       (expect 'open "[ after the interface alias")
       (define provisions
         (let loop ([backward '()])
           (define found (current))
           (case (token-kind found)
             [(close) (advance!) (reverse backward)]
             [(eof) (read-error source found "expected ] before end of file")]
             [else
              (define start (expect-word "provide"))
              (define part (named-word "a required part name"))
              (expect-word "by")
              (define locator
                (token-value (expect 'string "a quoted implementation reference")))
              (when (string=? locator "")
                (read-error source start "implementation reference cannot be empty"))
              (loop (cons (node 'provide (list part locator) '() start)
                          backward))])))
       (node 'implements (list path alias) provisions command)]
      ["must"
       (unless (and definitions-allowed? (not in-procedure?)
                    (not includes-allowed?) (not imports-allowed?))
         (read-error source command "must belongs directly in a workflow file"))
       (define form (expect 'word "do, stages, or a record name after must"))
       (match (token-value form)
         ["do" (node 'must-call (named-word "a procedure name") '() command)]
         ["stages"
          (expect-word "in")
          (expect-word "order")
          (expect 'open "[ after must stages in order")
          (define names
            (let loop ([backward '()])
              (case (token-kind (current))
                [(close) (advance!) (reverse backward)]
                [(eof) (read-error source (current) "expected ] after stage names")]
                [else
                 (define at (current))
                 (define name (identifier-name "an unquoted stage name" #t))
                 (when (member name backward)
                   (read-error source at (format "duplicate required stage ~s" name)))
                 (loop (cons name backward))])))
          (when (< (length names) 2)
            (read-error source command "must stages in order needs at least two stage names"))
          (node 'must-stage-order names '() command)]
         [_ (read-error source command "use subject implement Interface without a must prefix")])]
      ["stage"
       (when (or includes-allowed? imports-allowed?)
         (read-error source command "stage belongs in a workflow or procedure"))
       (define name (identifier-name "an unquoted stage name"))
       (define performer
         (and (eq? (token-kind (current)) 'word)
              (string=? (token-value (current)) "by")
              (begin (advance!) (named-word "a performer name"))))
       (if (and (eq? (token-kind (current)) 'word)
                (string=? (token-value (current)) "from"))
           (begin (advance!) (parse-state-stage name performer command in-procedure?))
           (if performer
               (read-error source command "stage by performer needs from state")
               (node 'stage name (parse-about) command)))]
      ["end" (read-error source command "end stage has no matching stage")]
      ["do"
       (if (eq? (token-kind (current)) 'open)
           (begin
             (advance!)
             (node 'sequence #f (parse-body #f in-procedure? #f #f) command))
           (let ([name (named-word "a procedure name")])
             (if (and (eq? (token-kind (current)) 'word)
                      (member (token-value (current)) '("by" "with" "into")))
                 (let* ([performer
                         (and (string=? (token-value (current)) "by")
                              (begin (advance!) (named-word "a performer name")))]
                        [mappings
                        (if (string=? (token-value (current)) "with")
                            (begin (advance!) (parse-state-mappings))
                            '())])
                   (expect-word "into")
                   (node 'state-call (list name (parse-location) performer)
                         mappings command))
                 (let ()
             (define arguments
               (let loop ([backward '()])
                 (define found (current))
                 (if (or (call-end?)
                         (and (eq? (token-kind found) 'word)
                              (string=? (token-value found) "as")))
                     (reverse backward)
                     (loop (cons (parse-value) backward)))))
             (define result-name
               (and (eq? (token-kind (current)) 'word)
                    (string=? (token-value (current)) "as")
                    (begin (advance!) (named-word "a result name"))))
             (when (and result-name
                        (regexp-match? #rx"[.]" (symbol->string result-name)))
               (read-error source command "a result name cannot contain a dot"))
             (node 'call (cons name result-name) arguments command)))))]
      ["repeat"
       (if (eq? (token-kind (current)) 'open)
           (begin
             (advance!)
             (let ([body (parse-body #f in-procedure? #f #f)])
               (expect-word "until")
               (node 'repeat-until (parse-condition) body command)))
           (let ([count (parse-value)])
             (expect 'open "[ after repeat count")
             (node 'repeat count (parse-body #f in-procedure? #f #f) command)))]
      ["for"
       (expect-word "each")
       (define name (named-word "a loop variable"))
       (when (regexp-match? #rx"[.]" (symbol->string name))
         (read-error source command "a loop name cannot contain a dot"))
       (expect-word "in")
       (define collection (parse-value))
       (expect 'open "[ after the collection")
       (node 'for-each (cons name collection)
             (parse-body #f in-procedure? #f #f) command)]
      ["set"
       (read-error source command "write name = value for assignment")]
      ["while"
       (define condition (parse-condition))
       (expect 'open "[ after while condition")
       (node 'while condition (parse-body #f in-procedure? #f #f) command)]
      ["if" (parse-if command in-procedure?)]
      ["print"
       (node 'print (parse-value) '() command)]
      ["output"
       (unless in-procedure?
         (read-error source command "output belongs inside a procedure"))
       (node 'output (parse-value) '() command)]
      [_
       (define name (token-value command))
       (unless (and (or (not (member name reserved))
                        (member name '("hypotheses" "assumptions" "conclusions")))
                    (not (regexp-match? #px"^[+-]?[0-9]" name)))
         (read-error source command
                     (format "unsupported command ~a in the first ScienceLogo slice"
                             name)))
       (define target (dotted-value command name))
       (cond
         [(and (eq? (token-kind (current)) 'word)
               (string=? (token-value (current)) "implement"))
          (parse-implementation target command)]
         [(and (eq? (token-kind (current)) 'word)
               (member (token-value (current)) '("=" "+=")))
          (define operator (token-value (advance!)))
          (define expression (parse-value))
          (define value
            (if (string=? operator "+=")
                (node 'augment #f (list target expression) command)
                expression))
          (if (eq? (node-kind target) 'result)
              (node 'assignment (cons (node-value target) value) '() command)
              (node 'path-assignment #f (list target value) command))]
         [(eq? (node-kind target) 'dot-update)
          (node 'path-update-command #f (list target) command)]
         [else
          (read-error source command "expected = or += after assignment target")])]))
  (define (parse-implementation subject command)
    (expect-word "implement")
    (define reference
      (if (eq? (token-kind (current)) 'string)
          (let ([path (token-value (advance!))])
            (when (or (string=? path "") (not (relative-path? (string->path path))))
              (read-error source command "interface file path must be relative"))
            path)
          (named-word "an interface or nested requirement reference")))
    (node 'implement reference (list subject) command))
  (define (parse-interface-entry command required?)
    (define name (token-value command))
    (when (or (member name reserved)
              (regexp-match? #px"^[+-]?[0-9]" name))
      (read-error source command "expected an interface field name"))
    (cond
      [(eq? (token-kind (current)) 'open)
       (advance!)
       (node (if required? 'required-interface-group 'interface-group)
             (string->symbol name) (parse-interface-body #t) command)]
      [(and (eq? (token-kind (current)) 'word)
            (string=? (token-value (current)) "is"))
       (define operator (advance!))
       (define target (named-word "a value kind or interface name after is"))
       (define receiver
         (if (string-contains? name ".") (dotted-value command name)
             (node 'result (string->symbol name) '() command)))
       (define constraint (node 'kind-test target (list receiver) operator))
       (node (if required? 'required-interface-field 'interface-field)
             (string->symbol name)
             (list (node 'field-constraint #f (list constraint) command)) command)]
      [else
       (define default
         (and (eq? (token-kind (current)) 'word)
              (string=? (token-value (current)) "=")
              (begin (advance!) (parse-value))))
       (define (unknown-default? value)
         (and value
              (or (and (eq? (node-kind value) 'group)
                       (unknown-default? (car (node-children value))))
                  (and (eq? (node-kind value) 'literal) (eq? (node-value value) 'unknown))
                  (and (eq? (node-kind value) 'uncertain)
                       (unknown-default? (car (node-children value)))))))
       (define declared-default
         (cond
           [(and (unknown-default? default) (eq? (token-kind (current)) 'word)
                 (memq (string->symbol (token-value (current))) value-kind-names))
            (define kind (advance!))
            (node 'typed-default (string->symbol (token-value kind)) (list default) kind)]
           [(and (unknown-default? default) (eq? (token-kind (current)) 'word)
                 (andmap valid-inline-interface-name?
                         (string-split (token-value (current)) "." #:trim? #f)))
            ;; Keep parsing the following entry normally. Once includes and
            ;; imports are known, a declared interface can identify this word
            ;; as a suffix instead. Its token prevents crossing must groups.
            (node 'pending-typed-default (string->symbol (token-value (current)))
                  (list default) (current))]
           [else default]))
       (node (if (or required? default) 'required-interface-field 'interface-field)
             (string->symbol name) (if declared-default (list declared-default) '()) command)]))
  (define (parse-required-entries)
    (expect 'open "[ after must in an interface")
    (let loop ([backward '()])
      (case (token-kind (current))
        [(close)
         (when (null? backward)
           (read-error source (current) "must [...] needs at least one entry"))
         (advance!)
         (reverse backward)]
        [(eof) (read-error source (current) "expected ] before end of file")]
        [else
         (define start index)
         (define command (current))
         (define expression (parse-value))
         (if (memq (node-kind (ungroup-node expression)) '(compare kind-test binary unary literal))
             (loop (cons (node 'interface-requirement expression '() command) backward))
             (begin
               (set! index start)
               (loop (cons (parse-interface-entry (expect 'word "a required interface entry") #t)
                           backward))))])))
  (define (parse-interface-if command)
    (define (branch condition at)
      (expect 'open "[ after interface condition or else")
      (node 'interface-branch condition (parse-interface-body #t) at))
    (define first (branch (parse-value) command))
    (define more
      (let loop ()
        (if (and (eq? (token-kind (current)) 'word)
                 (string=? (token-value (current)) "else"))
            (let ([at (advance!)])
              (if (and (eq? (token-kind (current)) 'word)
                       (string=? (token-value (current)) "if"))
                  (begin (advance!)
                         (cons (branch (parse-value) at) (loop)))
                  (list (branch #f at))))
            '())))
    (node 'interface-if #f (cons first more) command))
  (define (parse-interface-body [nested? #f])
    (let loop ([backward '()])
      (define found (current))
      (case (token-kind found)
        [(close) (advance!) (reverse backward)]
        [(eof) (read-error source found "expected ] before end of file")]
        [else
         (define command (expect 'word "an interface field, extends, version, must, or affects"))
         (define forms
           (match (token-value command)
             ["extends"
              (when nested? (read-error source command "extends belongs in the interface declaration"))
              (list (node 'extends (named-word "a parent interface name") '() command))]
             ["version"
              (when nested? (read-error source command "version belongs in the interface declaration"))
              (list (node 'version (token-value (expect 'string "a quoted interface version"))
                          '() command))]
             ["require"
              (read-error source command "use must [...] for required interface entries")]
             ["must" (parse-required-entries)]
             ["if" (list (parse-interface-if command))]
             ["for"
              (expect-word "each")
              (define name (named-word "a loop variable"))
              (when (regexp-match? #rx"[.]" (symbol->string name))
                (read-error source command "a loop name cannot contain a dot"))
              (expect-word "in")
              (define collection (parse-value))
              (expect 'open "[ after the collection")
              (list (node 'interface-for-each (cons name collection)
                          (parse-interface-body #t) command))]
             ["affects"
              (list (node 'affects
                          (list (named-word "a source part name")
                                (named-word "an affected part name"))
                          '() command))]
             [_ (list (parse-interface-entry command #f))]))
         (loop (append (reverse forms) backward))])))
  (define (parse-to-eof definitions-allowed? includes-allowed?)
    (let loop ([backward '()])
      (case (token-kind (current))
        [(eof) (reverse backward)]
        [(close) (read-error source (current) "unexpected ] at top level")]
        [else
         (loop (cons (parse-form definitions-allowed? #f includes-allowed? #f)
                     backward))])))
  (define start (current))
  (define first-word
    (and (eq? (token-kind start) 'word) (token-value start)))
  (define kind
    (cond
      [(equal? expected-kind "workflow-fragment") "workflow-fragment"]
      [(equal? expected-kind "fragment") "fragment"]
      [(member first-word '("library" "interface")) first-word]
      [else "workflow"]))
  (define-values (title imports forms)
    (cond
      [(string=? kind "workflow")
       (define leading-title
         (and (equal? first-word "workflow")
              (begin
                (advance!)
                (token-value (expect 'string "a quoted workflow title")))))
       (define description (parse-about))
       (define imports
         (let loop ([backward '()])
           (if (and (eq? (token-kind (current)) 'word)
                    (string=? (token-value (current)) "import"))
               (loop (cons (parse-import (advance!)) backward))
               (reverse backward))))
       (values leading-title imports (append description (parse-to-eof #t #f)))]
      [(string=? kind "fragment")
       (values #f '() (parse-to-eof #t #t))]
      [(string=? kind "workflow-fragment")
       (values #f '() (parse-to-eof #t #f))]
      [else
       (advance!)
       (define title (identifier-name (format "an unquoted ~a name" kind)))
       (expect 'open "[ after the library or interface name")
       (values title '()
               (if (string=? kind "interface")
                   (parse-interface-body)
                   (parse-body #t #f #t #t)))]))
  (define inline-first?
    (and (string=? kind "interface")
         (not (eq? (token-kind (current)) 'eof))
         (not (equal? expected-kind "interface"))))
  (define actual-kind (if inline-first? "workflow" kind))
  (when (and expected-kind (not (string=? actual-kind expected-kind)))
    (read-error source start (format "expected ~a declaration" expected-kind)))
  (define actual-forms
    (if inline-first?
        (let ([declaration (node 'interface title forms start)])
          (cons declaration (parse-to-eof #t #f)))
        forms))
  (unless (eq? (token-kind (current)) 'eof)
    (read-error source (current) "expected end of file after library or interface"))
  (when (member kind '("library" "fragment"))
    (for ([form (in-list forms)])
      (unless (memq (node-kind form) (if (string=? kind "library")
                                         '(to include import interface)
                                         '(to include interface)))
        (read-error source (node-at form)
                    "a library can contain only to, interface, include, and import declarations"))))
  (define workflow-forms
    (and (string=? actual-kind "workflow")
         (expand-workflow-forms actual-forms source)))
  (define result
    (case (string->symbol actual-kind)
      [(library) (node 'library title actual-forms start)]
      [(interface) (node 'interface title actual-forms start)]
      [(fragment) (node 'fragment #f actual-forms start)]
      [(workflow-fragment) (node 'workflow-fragment #f actual-forms start)]
      [(workflow) (node 'workflow (if inline-first? #f title)
                           (append (resolve-imports imports)
                                   workflow-forms) start)]))
  (define normalized-result
    (if (memq (node-kind result) '(workflow interface))
        (resolve-typed-defaults (resolve-value-references result)) result))
  (cond
    [(memq (node-kind result) '(fragment workflow-fragment)) result]
    [(eq? (node-kind result) 'interface)
     (validate-interface normalized-result source)
     (for ([form (in-list (node-children normalized-result))]
           #:when (eq? (node-kind form) 'extends))
       (read-error source (node-at form)
                   "standalone interfaces cannot extend a local interface"))
     (define name (string->symbol (node-value result)))
     (define resolved
       (resolve-record-interfaces (hasheq name (map node->datum (node-children normalized-result)))))
     (validate-kind-targets normalized-result resolved source)
     (validate-interface-guards
      normalized-result (hash-ref resolved name) source)
     normalized-result]
    [(and (eq? (node-kind result) 'library) (not expand-local?)) result]
    [(eq? (node-kind result) 'library)
     (define directory (path-only (path->complete-path source)))
     (define expanded
       (struct-copy node result
                    [children
                     (expand-library-forms
                      forms
                      (lambda (path at)
                        (define full (build-path directory (string->path path)))
                        (unless (file-exists? full)
                          (read-error source at (format "missing included file ~a" path)))
                        (file->string full))
                      (format "~a" source))]))
     (define local-imports
       (filter (lambda (form) (eq? (node-kind form) 'import))
               (node-children expanded)))
     (define assembled
       (struct-copy node expanded
                    [children (append (resolve-imports local-imports)
                                      (filter (lambda (form)
                                                (not (eq? (node-kind form) 'import)))
                                              (node-children expanded)))]))
     (define names (interface-names-in assembled))
     (define checked (resolve-typed-defaults (resolve-value-references assembled names) names))
     (check-direct-calls
      (node-children (resolve-typed-defaults (resolve-value-references expanded names) names)) source names)
     (validate-program checked source)
     checked]
    [else
     (when (eq? (node-kind result) 'workflow)
       (check-direct-calls
        (node-children
         (resolve-typed-defaults
          (resolve-value-references (struct-copy node result [children workflow-forms])
                                    (interface-names-in result))
          (interface-names-in result))) source (interface-names-in result)))
     (validate-program normalized-result source)
     normalized-result]))

(define (interface-names-in tree)
  (if (eq? (node-kind tree) 'interface) (list (string->symbol (node-value tree)))
      (for/list ([form (in-list (node-children tree))] #:when (eq? (node-kind form) 'interface))
        (string->symbol (node-value form)))))

(define (stage-names-in tree)
  (append
   (case (node-kind tree)
     [(stage) (list (node-value tree))]
     [(state-stage) (list (car (node-value tree)))]
     [else '()])
   (append* (map stage-names-in (node-children tree)))))

;; Dots are parsed uniformly first. Once imports and includes are assembled,
;; recognize declared interface roots and stage mapping targets by their
;; complete names, never by case or by quoting an identifier.
(define (resolve-value-references tree [names (interface-names-in tree)]
                                  [stage-names (stage-names-in tree)])
  (define interfaces (for/hasheq ([name (in-list names)]) (values name #t)))
  (define (path-name value)
    (case (node-kind value)
      [(result) (symbol->string (node-value value))]
      [(field-ref)
       (define parent (path-name (car (node-children value))))
       (and parent (format "~a.~a" parent (node-value value)))]
      [else #f]))
  (define (walk-value value)
    (cond [(node? value) (walk value)]
          [(pair? value) (cons (walk-value (car value)) (walk-value (cdr value)))]
          [else value]))
  (define (walk form)
    (define resolved
      (struct-copy node form
                   [value (walk-value (node-value form))]
                   [children (map walk (node-children form))]))
    (when (eq? (node-kind resolved) 'implement)
      (define subject (car (node-children resolved)))
      (define name (path-name subject))
      (when (and name (member name stage-names))
        (set! resolved
              (struct-copy node resolved
                           [children (list (node 'stage-reference name '() (node-at subject)))]))))
    (define path (and (eq? (node-kind resolved) 'field-ref) (path-name resolved)))
    (if (and path (hash-has-key? interfaces (string->symbol path)))
        (node 'result (string->symbol path) '() (node-at resolved))
        resolved))
  (walk tree))

(define (resolve-typed-defaults tree [names (interface-names-in tree)])
  (define interfaces (for/hasheq ([name (in-list names)]) (values name #t)))
  (define (walk form)
    (struct-copy node form [children (walk-forms (node-children form))]))
  (define (walk-forms forms)
    (cond
      [(null? forms) '()]
      [else
       (define form (car forms))
       (define pending
         (and (memq (node-kind form) '(interface-field required-interface-field))
              (pair? (node-children form))
              (eq? (node-kind (car (node-children form))) 'pending-typed-default)
              (car (node-children form))))
       (cond
         [pending
          (define next (and (pair? (cdr forms)) (cadr forms)))
          (define suffix?
            (and next (memq (node-kind next) '(interface-field required-interface-field))
                 (null? (node-children next)) (equal? (node-at next) (node-at pending))
                 (interface-reference-root interfaces (node-value pending))))
          (define default
            (if suffix? (struct-copy node pending [kind 'typed-default])
                (car (node-children pending))))
          (cons (struct-copy node form [children (list (walk default))])
                (walk-forms (if suffix? (cddr forms) (cdr forms))))]
         [else (cons (walk form) (walk-forms (cdr forms)))])]))
  (walk tree))

(define (parse-program in source)
  (node->datum (parse-tree in source)))

(define (git-output source at operation . args)
  (define git (find-executable-path "git"))
  (unless git
    (read-error source at "Git is required to import a library"))
  (define output (open-output-string))
  (define status
    (parameterize ([current-output-port output]
                   [current-error-port (open-output-string)])
      (apply system*/exit-code git args)))
  (unless (zero? status)
    (read-error source at (format "could not ~a" operation)))
  (get-output-string output))

(define (parse-library-file content source kind at)
  (define port (open-input-string content))
  (port-count-lines! port)
  (define first-line (read-line port 'any))
  (unless (and (string? first-line)
               (string=? (string-trim first-line) "#lang sciencelogo"))
    (read-error source at "included source must begin with #lang sciencelogo"))
  (parse-tree port source kind #f))

(define (include-path current requested at)
  (unless (and (not (string=? requested ""))
               (not (string-prefix? requested "/"))
               (not (string-contains? requested "\\"))
               (not (regexp-match? #px"^[A-Za-z]:" requested)))
    (read-error (token-source at) at "include path must be relative"))
  (define parent (drop-right (string-split current "/") 1))
  (define parts
    (for/fold ([backward (reverse parent)])
              ([part (in-list (string-split requested "/" #:trim? #f))])
      (cond
        [(string=? part "")
         (read-error (token-source at) at "include path has an empty component")]
        [(string=? part ".") backward]
        [(string=? part "..")
         (if (null? backward)
             (read-error (token-source at) at
                         "include path escapes the library repository")
             (cdr backward))]
        [else (cons part backward)])))
  (unless (pair? parts)
    (read-error (token-source at) at "include path must name a file"))
  (string-join (reverse parts) "/"))

(define (expand-library-forms forms read-file source-label)
  (define seen (make-hash))
  (define active (make-hash))
  (hash-set! seen "library.rkt" #t)
  (hash-set! active "library.rkt" #t)
  (define (expand forms current)
    (apply append
           (for/list ([form (in-list forms)])
             (if (eq? (node-kind form) 'include)
                 (let ([path (include-path current (node-value form) (node-at form))])
                   (when (hash-has-key? active path)
                     (read-error (token-source (node-at form)) (node-at form)
                                 (format "include cycle through ~a" path)))
                   (when (hash-has-key? seen path)
                     (read-error (token-source (node-at form)) (node-at form)
                                 (format "duplicate include ~a" path)))
                   (hash-set! seen path #t)
                   (hash-set! active path #t)
                   (define fragment
                     (parse-library-file (read-file path (node-at form))
                                         (format "~a:~a" source-label path)
                                         "fragment" (node-at form)))
                   (define result (expand (node-children fragment) path))
                   (hash-remove! active path)
                   result)
                 (list form)))))
  (expand forms "library.rkt"))

(define (expand-workflow-forms forms source)
  (define entry (simplify-path (path->complete-path source)))
  (define root #f)
  (define seen (make-hash))
  (define active (make-hash))
  (hash-set! seen entry #t)
  (hash-set! active entry #t)
  (define (repository-root at)
    (unless root
      (define directory (path-only entry))
      (set! root
            (simplify-path
             (string->path
              (string-trim
               (git-output source at "find the workflow Git repository"
                           "-C" (path->string directory)
                           "rev-parse" "--show-toplevel")))
             #t)))
    root)
  (define (inside-root? path base)
    (define relative (find-relative-path base path))
    (and (relative-path? relative)
         (not (for/or ([part (in-list (explode-path relative))])
                (eq? part 'up)))))
  (define (expand body current)
    (apply append
           (for/list ([form (in-list body)])
             (if (eq? (node-kind form) 'include)
                 (let* ([requested (node-value form)]
                        [at (node-at form)]
                        [base (repository-root at)])
                   (when (or (string=? requested "")
                             (not (relative-path? (string->path requested)))
                             (string-contains? requested "\\"))
                     (read-error source at "include path must be relative"))
                   (define candidate
                     (simplify-path
                      (build-path (path-only current) (string->path requested))))
                   (unless (inside-root? candidate base)
                     (read-error source at "include path escapes the workflow repository"))
                   (unless (file-exists? candidate)
                     (read-error source at (format "missing included file ~a" requested)))
                   (define full (simplify-path candidate #t))
                   (unless (inside-root? full base)
                     (read-error source at "include path escapes the workflow repository"))
                   (when (hash-has-key? active full)
                     (read-error source at (format "include cycle through ~a" requested)))
                   (when (hash-has-key? seen full)
                     (read-error source at (format "duplicate include ~a" requested)))
                   (hash-set! seen full #t)
                   (hash-set! active full #t)
                   (define fragment
                     (parse-library-file (file->string full) (path->string full)
                                         "workflow-fragment" at))
                   (define children (expand (node-children fragment) full))
                   (hash-remove! active full)
                   (cons (node 'included-file
                               (list (path->string full)
                                     (call-with-input-file full sha1))
                               '() at)
                         children))
                 (list form)))))
  (expand forms entry))

(define (qualify-library-form form alias interface-names [procedure-names '()] [bound '()])
  (define (qualified name)
    (string->symbol (format "~a.~a" alias name)))
  (define (qualify-value value)
    (cond
      [(not (node? value)) value]
      [(memq (node-kind value) '(kind-test typed-default))
       (define target (node-value value))
       (define root
         (and (not (memq target value-kind-names))
              (interface-reference-root
               (for/hasheq ([name (in-list interface-names)]) (values name #t)) target)))
       (struct-copy node value
                    [value (if root (qualified target) target)]
                    [children (map qualify-value (node-children value))])]
      [(and (eq? (node-kind value) 'result)
            (memq (node-value value) interface-names))
       (struct-copy node value [value (qualified (node-value value))])]
      [else
       (struct-copy node value
                    [children (map qualify-value (node-children value))])]))
  (define (qualify-form child)
    (qualify-library-form child alias interface-names procedure-names bound))
  (define (qualify-body forms [locals bound])
    (define-values (result _locals)
      (for/fold ([result '()] [locals locals]) ([child (in-list forms)])
        (values
         (cons (qualify-library-form child alias interface-names procedure-names locals) result)
         (case (node-kind child)
           [(assignment) (cons (car (node-value child)) locals)]
           [(call) (if (cdr (node-value child))
                       (cons (cdr (node-value child)) locals) locals)]
           [else locals]))))
    (reverse result))
  (case (node-kind form)
    [(interface)
     (struct-copy node form
                  [value (symbol->string (qualified (node-value form)))]
                  [children (map qualify-form (node-children form))])]
    [(extends)
     (struct-copy node form [value (qualified (node-value form))])]
    [(interface-group required-interface-group interface-if)
     (struct-copy node form [children (map qualify-form (node-children form))])]
    [(interface-branch interface-requirement)
     (struct-copy node form
                  [value (and (node-value form) (qualify-value (node-value form)))]
                  [children (map qualify-form (node-children form))])]
    [(interface-for-each)
     (struct-copy node form
                  [value (cons (car (node-value form)) (qualify-value (cdr (node-value form))))]
                  [children (map qualify-form (node-children form))])]
    [(interface-field required-interface-field)
     (struct-copy node form
                  [children (map qualify-value (node-children form))])]
    [(stage)
     (struct-copy node form
                  [value (format "~a.~a" alias (node-value form))])]
    [(state-stage)
     (struct-copy node form
                  [value (cons (format "~a.~a" alias (car (node-value form)))
                               (cdr (node-value form)))]
                  [children (qualify-body (node-children form))])]
    [(to)
     (struct-copy node form
                  [value (cons (qualified (procedure-name form))
                               (procedure-inputs form))]
                  [children (qualify-body (node-children form) (procedure-inputs form))])]
    [(implement)
     (define reference (node-value form))
     (define subject (car (node-children form)))
     (define root
       (and (symbol? reference)
            (interface-reference-root
             (for/hasheq ([name (in-list interface-names)]) (values name #t)) reference)))
     (struct-copy node form
                  [value (if root (qualified reference) reference)]
                  [children
                   (list
                    (cond
                      [(eq? (node-kind subject) 'stage-reference)
                       (struct-copy node subject [value (format "~a.~a" alias (node-value subject))])]
                      [(and (eq? (node-kind subject) 'result)
                            (memq (node-value subject) procedure-names)
                            (not (memq (node-value subject) bound)))
                       (struct-copy node subject [value (qualified (node-value subject))])]
                      [else (qualify-value subject)]))])]
    [(call)
     (struct-copy node form
                  [value (cons (qualified (call-name form))
                               (cdr (node-value form)))]
                  [children (map qualify-value (node-children form))])]
    [(state-call)
     (struct-copy node form
                  [value (cons (qualified (call-name form))
                               (cdr (node-value form)))])]
    [(assignment)
     (struct-copy node form
                  [value (cons (car (node-value form))
                               (qualify-value (cdr (node-value form))))])]
    [(print output)
     (struct-copy node form [value (qualify-value (node-value form))])]
    [(repeat repeat-until while)
     (struct-copy node form
                  [value (qualify-value (node-value form))]
                  [children (qualify-body (node-children form))])]
    [(for-each)
     (struct-copy node form
                  [value (cons (car (node-value form))
                               (qualify-value (cdr (node-value form))))]
                  [children (qualify-body (node-children form)
                                          (cons (car (node-value form)) bound))])]
    [(branch)
     (struct-copy node form
                  [value (and (node-value form)
                              (qualify-value (node-value form)))]
                  [children (qualify-body (node-children form))])]
    [(sequence if)
     (struct-copy node form
                  [children (qualify-body (node-children form))])]
    [else form]))

(define (load-library import parent-alias stack)
  (define at (node-at import))
  (define source (token-source at))
  (match-define (list url revision alias) (node-value import))
  (when (member url stack)
    (read-error source at (format "library import cycle through ~a" url)))
  (unless (regexp-match? #rx"^(https://|file://)" url)
    (read-error source at "library URL must begin with https:// or file://"))
  (when (string=? revision "")
    (read-error source at "library tag or commit cannot be empty"))
  (define qualified-alias
    (if parent-alias
        (string->symbol (format "~a.~a" parent-alias alias))
        alias))
  (define checkout (make-temporary-file "sciencelogo-library-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (git-output source at "fetch library repository"
                  "clone" "--quiet" "--no-checkout" url (path->string checkout))
      (define (git-in operation . args)
        (apply git-output source at operation "-C" (path->string checkout) args))
      (define reference
        (if (regexp-match? #px"^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$" revision)
            (string-append revision "^{commit}")
            (string-append "refs/tags/" revision "^{commit}")))
      (define commit (string-trim (git-in "resolve library tag or commit"
                                         "rev-parse" "--verify" reference)))
      (git-in "verify library revision is on main"
              "merge-base" "--is-ancestor" commit "refs/remotes/origin/main")
      (define content
        (git-in "read library.rkt at the selected revision"
                "show" (string-append commit ":library.rkt")))
      (define source-label (format "~a at ~a" url commit))
      (define library
        (parse-library-file content (format "~a:library.rkt" source-label)
                            "library" at))
      (define expanded
        (struct-copy node library
                     [children
                      (expand-library-forms
                       (node-children library)
                       (lambda (path include-at)
                         (git-output source include-at "read included library file"
                                     "-C" (path->string checkout) "show"
                                     (string-append commit ":" path)))
                       source-label)]))
      (define local-imports
        (filter (lambda (form) (eq? (node-kind form) 'import))
                (node-children expanded)))
      (define dependencies
        (resolve-imports local-imports qualified-alias (cons url stack)))
      (define alias-prefix (format "~a." qualified-alias))
      (define interface-names
        (append
         (for/list ([form (in-list (node-children expanded))]
                    #:when (eq? (node-kind form) 'interface))
           (string->symbol (node-value form)))
         (for/list ([form (in-list dependencies)]
                    #:when (and (eq? (node-kind form) 'interface)
                                (string-prefix? (node-value form) alias-prefix)))
           (string->symbol
            (substring (node-value form) (string-length alias-prefix))))))
      (define normalized-expanded
        (resolve-typed-defaults
         (resolve-value-references
          expanded interface-names
          (append (stage-names-in expanded)
                  (for/list ([name (in-list (append* (map stage-names-in dependencies)))]
                             #:when (string-prefix? name alias-prefix))
                    (substring name (string-length alias-prefix)))))
         interface-names))
      (check-direct-calls (node-children normalized-expanded) source interface-names)
      (define local-definitions
        (map (lambda (form)
               (qualify-library-form
                form qualified-alias interface-names
                (map procedure-name
                     (filter (lambda (form) (eq? (node-kind form) 'to))
                             (node-children normalized-expanded)))))
             (filter (lambda (form) (memq (node-kind form) '(to interface)))
                     (node-children normalized-expanded))))
      (define definitions (append dependencies local-definitions))
      (validate-program (struct-copy node expanded [children definitions]) source)
      (values (struct-copy node import
                           [value (list url revision commit qualified-alias
                                        (node-value library))])
              definitions))
    (lambda () (delete-directory/files checkout))))

(define (resolve-imports imports [parent-alias #f] [stack '()])
  (define aliases (make-hasheq))
  (apply append
         (for/list ([import (in-list imports)])
           (define alias (caddr (node-value import)))
           (when (hash-has-key? aliases alias)
             (read-error (token-source (node-at import)) (node-at import)
                         (format "duplicate import alias ~a" alias)))
           (hash-set! aliases alias #t)
           (define-values (resolved definitions)
             (load-library import parent-alias stack))
           (cons resolved definitions))))

(define (calls-in forms)
  (for/fold ([calls '()]) ([form (in-list forms)])
    (case (node-kind form)
      [(call state-call) (cons form calls)]
      [(sequence repeat repeat-until for-each while if branch to state-stage)
       (append (calls-in (node-children form)) calls)]
      [else calls])))

(define (check-direct-calls forms source [interface-names '()])
  (define local-interfaces
    (for/hasheq ([form (in-list forms)] #:when (eq? (node-kind form) 'interface))
      (values (string->symbol (node-value form)) form)))
  (define known-interfaces
    (for/fold ([known local-interfaces]) ([name (in-list interface-names)])
      (hash-set known name #t)))
  (define (check-private-name name at [interface-reference? #f])
    (define root
      (and interface-reference? (symbol? name)
           (interface-reference-root known-interfaces name)))
    (when (and (symbol? name)
               (regexp-match? #rx"[.].*[.]" (symbol->string name))
               ;; Declarations are either local (Shape) or directly imported
               ;; (tools.Shape). Deeper declaration roots belong to private
               ;; dependencies; nested public parts share their public root.
               (not (and root
                         (not (regexp-match? #rx"[.].*[.]" (symbol->string root))))))
      (read-error source at
                  "a library dependency is private; import it directly to use it")))
  (for ([call (in-list (calls-in forms))])
    (when (regexp-match? #rx"[.].*[.]" (symbol->string (call-name call)))
      (read-error source (node-at call)
                  "a library dependency is private; import it directly to call it")))
  (define (check-form form)
    (when (memq (node-kind form) '(result extends))
      (check-private-name (node-value form) (node-at form)))
    (when (memq (node-kind form) '(kind-test typed-default))
      (check-private-name (node-value form) (node-at form) #t))
    (case (node-kind form)
      [(implement)
       (check-private-name (node-value form) (node-at form) #t)
       (check-form (car (node-children form)))]
      [else
       (define value (node-value form))
       (cond [(node? value) (check-form value)]
             [(and (pair? value) (node? (cdr value)))
              (check-form (cdr value))])])
    (for ([child (in-list (node-children form))])
      (check-form child)))
  (for ([form (in-list forms)]) (check-form form)))

(define (call-name call) (car (node-value call)))
(define (procedure-name definition) (car (node-value definition)))
(define (procedure-inputs definition) (cdr (node-value definition)))

(define (has-output? forms)
  (for/or ([form (in-list forms)])
    (or (eq? (node-kind form) 'output)
        (and (memq (node-kind form)
                   '(sequence repeat repeat-until for-each while if branch))
             (has-output? (node-children form))))))

(define (always-outputs? forms)
  (for/or ([form (in-list forms)])
    (case (node-kind form)
      [(output) #t]
      [(sequence repeat-until) (always-outputs? (node-children form))]
      [(repeat)
       (define count (ungroup-node (node-value form)))
       (and (eq? (node-kind count) 'literal)
            (exact-positive-integer? (node-value count))
            (always-outputs? (node-children form)))]
      [(if)
       (define branches (node-children form))
       (and (pair? branches)
            (not (node-value (last branches)))
            (andmap (lambda (branch)
                      (always-outputs? (node-children branch)))
                    branches))]
      [else #f])))

(define (state-paths state source)
  (define seen (make-hash))
  (define (walk value prefix)
    (set! value (ungroup-node value))
    (case (node-kind value)
      [(fields)
       (for ([entry (in-list (node-children value))])
         (define name (node-value entry))
         (when (regexp-match? #rx"[.]" (symbol->string name))
           (read-error source (node-at entry)
                       "state field names cannot contain a dot"))
         (define path (append prefix (list name)))
         (define child (car (node-children entry)))
         (hash-set! seen path (node->datum child))
         (walk child path))]
      [(list)
       (for ([child (in-list (node-children value))]
             [position (in-naturals 1)])
         (define path (append prefix (list position)))
         (hash-set! seen path (node->datum child))
         (walk child path))]
      [else (void)]))
  (for ([entry (in-list (node-children (ungroup-node state)))])
    (define root (node-value entry))
    (unless (memq root '(information environment factors))
      (read-error source (node-at entry)
                  "state sets must be information, environment, or factors"))
    (define value (ungroup-node (car (node-children entry))))
    (unless (or (eq? (node-kind value) 'fields)
                (and (eq? (node-kind value) 'list)
                     (null? (node-children value))))
      (read-error source (node-at entry)
                  (format "state set ~a needs named fields or []" root)))
    (hash-set! seen (list root) (node->datum value))
    (walk value (list root)))
  seen)

(define (validate-interface interface source)
  (when (string=? (node-value interface) "")
    (read-error source (node-at interface) "interface name cannot be empty"))
  (define versions
    (filter (lambda (form) (eq? (node-kind form) 'version))
            (node-children interface)))
  (when (> (length versions) 1)
    (read-error source (node-at interface)
                "an interface can have at most one version declaration"))
  (when (and (pair? versions) (string=? (node-value (car versions)) ""))
    (read-error source (node-at (car versions)) "interface version cannot be empty"))
  (define required (make-hasheq))
  (define fields (make-hasheq))
  (define requirements '())
  (define parents (make-hasheq))
  (define effects '())
  (define (qualified prefix name)
    (string->symbol (string-append prefix (symbol->string name))))
  (define (walk forms [prefix ""])
    (for ([form (in-list forms)])
      (case (node-kind form)
        [(interface-field required-interface-field interface-group required-interface-group)
         (define name (qualified prefix (node-value form)))
         (when (hash-has-key? fields name)
           (read-error source (node-at form) (format "duplicate interface field ~a" name)))
         (when (memq (node-kind form) '(required-interface-field required-interface-group))
           (hash-set! required name #t))
         (hash-set! fields name #t)
         (when (memq (node-kind form) '(interface-group required-interface-group))
           (walk (node-children form) (string-append (symbol->string name) ".")))]
        [(interface-if)
         (for ([branch (in-list (node-children form))])
           (walk (node-children branch) prefix))]
        [(interface-requirement)
         (set! requirements (cons form requirements))
         (for ([path (in-list (requirement-references (node->datum (node-value form))))])
           (hash-set! required (qualified prefix (car path)) #t))]
        [(interface-for-each)
         (set! requirements (cons form requirements))
         (when (pair? (node-children form))
           (validate-interface (node 'interface "list item" (node-children form) (node-at form)) source))]
        [(affects) (set! effects (cons (cons prefix form) effects))])))
  (walk (node-children interface))
  (for ([form (in-list (node-children interface))]
        #:when (eq? (node-kind form) 'extends))
    (define parent (node-value form))
    (when (hash-has-key? parents parent)
      (read-error source (node-at form) (format "duplicate parent interface ~a" parent)))
    (hash-set! parents parent #t))
  (when (and (zero? (hash-count required)) (zero? (hash-count fields))
             (zero? (hash-count parents)) (null? requirements))
    (read-error source (node-at interface)
                "an interface needs a field, parent, or required part"))
  (for ([effect (in-list effects)])
    (define prefix (car effect))
    (define form (cdr effect))
    (for ([part (in-list (node-value form))])
      (unless (hash-has-key? required (qualified prefix part))
        (read-error source (node-at form)
                    (format "impact references unknown part ~a" part))))))

(define (validate-kind-targets tree interfaces source)
  (define (walk value)
    (cond
      [(node? value)
       (when (and (memq (node-kind value) '(kind-test typed-default))
                  (not (memq (node-value value) value-kind-names))
                  (not (resolve-interface-reference interfaces (node-value value))))
         (read-error source (node-at value)
                     (format "unknown interface ~a after ~a" (node-value value)
                             (if (eq? (node-kind value) 'kind-test) "is" "unknown default"))))
       (walk (node-value value))
       (walk (node-children value))]
      [(pair? value) (walk (car value)) (walk (cdr value))]))
  (walk tree))

(define (validate-interface-guards declaration template source)
  (define (check fields requirements [outer-names '()] [binder #f])
    (define names
      (append
       (map (lambda (field)
              (string->symbol (car (string-split (symbol->string (record-field-name field)) "."))))
            fields)
       outer-names
       (if binder (list binder) '())
       (if binder '()
           (append* (map (lambda (requirement)
                           (map car (requirement-references (record-requirement-expression requirement))))
                         requirements)))))
    (define (expression value)
      (when (pair? value)
        (case (car value)
          [(literal) (void)]
          [(parameter)
           (read-error source (node-at declaration)
                       "interface conditions refer to interface entries, not procedure inputs")]
          [(result)
           (unless (memq (cadr value) names)
             (read-error source (node-at declaration)
                         (format "unknown interface entry ~a in condition" (cadr value))))]
          [(field-ref) (expression (caddr value))]
          [(fields) (for ([entry (in-list (cadr value))]) (expression (cadr entry)))]
          [(dot-select)
           (expression (caadr value))
           (for ([selector (in-list (cdadr value))]
                 #:unless (eq? (car (ungroup-expression selector)) 'result))
             (expression selector))]
          [(compare)
           (match value
             [`(compare in (,left ,right))
              (unless (match (ungroup-expression left) [`(result ,_) #t] [_ #f])
                (expression left))
              (expression right)]
             [_ (for ([part (in-list value)]) (expression part))])]
          [else (for ([part (in-list value)]) (expression part))])))
    (for ([field (in-list fields)])
      (when (and binder
                 (not (eq? binder (string->symbol
                                   (car (string-split (symbol->string (record-field-name field)) "."))))))
        (read-error source (node-at declaration)
                    (format "entries inside for each must refer to its item ~a" binder)))
      (expression (record-field-guard field))
      (when binder (expression (record-field-default field)))
      (when (record-field-children field)
        (check (record-field-children field) (record-field-requirements field)))
      (unless (record-field-children field)
        (for ([requirement (in-list (record-field-requirements field))])
          (expression (record-requirement-expression requirement)))))
    (for ([requirement (in-list requirements)])
      (define value (record-requirement-expression requirement))
      (match value
        [`(interface-for-each ,name ,collection ,body)
         (expression collection)
         (define local (iteration-template body))
         (check (record-interface-fields local) (record-interface-requirements local) names name)]
        [_ (expression value)])
      (expression (record-requirement-guard requirement))))
  (check (record-interface-fields template) (record-interface-requirements template)))

(define (validate-program program source)
  (define definitions (make-hasheq))
  (define interfaces (make-hasheq))
  (define performers (make-hasheq))
  (define resources (make-hasheq))
  (define propositions (make-hash))
  (for ([form (in-list (node-children program))]
        #:when (eq? (node-kind form) 'interface))
    (define name (string->symbol (node-value form)))
    (when (hash-has-key? interfaces name)
      (read-error source (node-at form) (format "duplicate interface ~a" name)))
    (validate-interface form source)
    (hash-set! interfaces name form))
  (define resolved-interfaces
    (resolve-record-interfaces
   (for/hasheq ([(name form) (in-hash interfaces)])
     (values name (map node->datum (node-children form))))
   (lambda (name message)
     (read-error source (node-at (hash-ref interfaces name)) message))))
  (validate-kind-targets program resolved-interfaces source)
  (for ([(name declaration) (in-hash interfaces)])
    (validate-interface-guards declaration (hash-ref resolved-interfaces name) source))
  (for ([form (in-list (node-children program))]
        #:when (eq? (node-kind form) 'to))
    (define name (procedure-name form))
    (when (hash-has-key? definitions name)
      (read-error source (node-at form) (format "duplicate procedure ~a" name)))
    (hash-set! definitions name form))
  (for ([name (in-hash-keys interfaces)])
    (when (hash-has-key? definitions name)
      (read-error source (node-at (hash-ref interfaces name))
                  (format "interface name ~a conflicts with a procedure" name))))
  (for ([form (in-list (node-children program))]
        #:when (eq? (node-kind form) 'performer))
    (define name (node-value form))
    (when (hash-has-key? performers name)
      (read-error source (node-at form) (format "duplicate performer ~a" name)))
    (when (or (hash-has-key? definitions name)
              (hash-has-key? interfaces name))
      (read-error source (node-at form)
                  (format "performer name ~a conflicts with another definition" name)))
    (hash-set! performers name form))
  (for ([form (in-list (node-children program))]
        #:when (eq? (node-kind form) 'resource))
    (define name (node-value form))
    (when (hash-has-key? resources name)
      (read-error source (node-at form) (format "duplicate resource ~a" name)))
    (when (or (hash-has-key? definitions name)
              (hash-has-key? interfaces name)
              (hash-has-key? performers name)
              (memq name '(information environment factors))
              (for/or ([other (in-list (node-children program))])
                (case (node-kind other)
                  [(import) (eq? name (list-ref (node-value other) 3))]
                  [(implements) (eq? name (second (node-value other)))]
                  [else #f])))
      (read-error source (node-at form)
                  (format "resource name ~a conflicts with another definition" name)))
    (hash-set! resources name form))
  (for ([form (in-list (node-children program))]
        #:when (eq? (node-kind form) 'proposition))
    (define key (node-value form))
    (when (hash-has-key? propositions key)
      (read-error source (node-at form)
                  (format "duplicate ~a ~a" (first key) (second key))))
    (hash-set! propositions key form))
  (define (path-root value)
    (set! value (ungroup-node value))
    (case (node-kind value)
      [(result) (node-value value)]
      [(field-ref dot-select dot-update)
       (path-root (car (node-children value)))]
      [else #f]))
  (define (resource-path? value)
    (set! value (ungroup-node value))
    (and (memq (node-kind value) '(field-ref dot-select))
         (hash-has-key? resources (path-root value))))
  (define (check-performer name at)
    (unless (hash-has-key? performers name)
      (read-error source at (format "unknown performer ~a" name))))
  (define stage-names (make-hash))
  (define (check-stage-names forms)
    (for ([form (in-list forms)])
      (case (node-kind form)
        [(stage)
         (define name (node-value form))
         (when (hash-has-key? stage-names name)
           (read-error source (node-at form) (format "duplicate stage ~s" name)))
         (hash-set! stage-names name #t)]
        [(state-stage)
         (define name (car (node-value form)))
         (when (hash-has-key? stage-names name)
           (read-error source (node-at form) (format "duplicate stage ~s" name)))
         (hash-set! stage-names name #t)
         (check-stage-names (node-children form))]
        [(to sequence repeat repeat-until for-each while if branch)
         (check-stage-names (node-children form))]
        [else (void)])))
  (check-stage-names (node-children program))
  (define (check-value value inputs results)
    (case (node-kind value)
      [(compare)
       (match (node-children value)
         [(list left right)
          (unless (and (eq? (node-value value) 'in) (eq? (node-kind (ungroup-node left)) 'result))
            (check-value left inputs results))
          (check-value right inputs results)])]
      [(group list fields field-entry proposition-value uncertain range kind-test typed-default binary unary augment
             dot-update)
       (for ([part (in-list (node-children value))])
         (check-value part inputs results))]
      [(field-ref)
       (unless (resource-path? value)
         (check-value (car (node-children value)) inputs results))]
      [(dot-select)
       (unless (resource-path? value)
         (check-value (car (node-children value)) inputs results))]
      [(parameter)
       (unless (memq (node-value value) inputs)
         (read-error source (node-at value)
                     (format "unknown input :~a" (node-value value))))]
      [(result)
       (unless (or (memq (node-value value) results)
                   (hash-has-key? interfaces (node-value value))
                   (hash-has-key? performers (node-value value))
                   (memq (node-value value) '(hypotheses assumptions conclusions)))
         (read-error source (node-at value)
                     (format "unknown result ~a" (node-value value))))]))
  (define (check-state-stage stage)
    (define entry (second (node-value stage)))
    (define exit-state (third (node-value stage)))
    (define default-performer (fourth (node-value stage)))
    (when default-performer
      (check-performer default-performer (node-at stage)))
    (define entry-paths (state-paths entry source))
    (define exit-paths (state-paths exit-state source))
    (define written (make-hash))
    (define controls (make-hasheq))
    (define (state-path value)
      (set! value (ungroup-node value))
      (case (node-kind value)
        [(result)
         (and (memq (node-value value) '(information environment factors))
              (list (node-value value)))]
        [(field-ref)
         (define parent (state-path (car (node-children value))))
         (and parent (append parent (list (node-value value))))]
        [(dot-select)
         (define parent (state-path (car (node-children value))))
         (and parent
              (= (length (node-children value)) 2)
              (let* ([selector (ungroup-node (second (node-children value)))]
                     [position
                      (case (node-kind selector)
                        [(literal) (node-value selector)]
                        [(result) (list 'index (node-value selector))]
                        [else #f])])
                (unless (or (exact-positive-integer? position)
                            (and (pair? position)
                                 (hash-has-key? controls (cadr position))))
                  (read-error source (node-at selector)
                              "state list position needs a positive number or stage control name"))
                (append parent (list position))))]
        [else #f]))
    (define (control-expression? value [known entry-paths])
      (set! value (ungroup-node value))
      (case (node-kind value)
        [(literal) (exact-integer? (node-value value))]
        [(result) (hash-has-key? controls (node-value value))]
        [(field-ref)
         (define path (state-path value))
         (and path (list-count-path? known path))]
        [(unary)
         (and (eq? (node-value value) '-)
              (control-expression? (car (node-children value)) known))]
        [(binary)
         (and (memq (node-value value) '(+ - *))
              (andmap (lambda (part) (control-expression? part known)) (node-children value)))]
        [else #f]))
    (define (control-collection? value [known entry-paths])
      (set! value (ungroup-node value))
      (case (node-kind value)
        [(list range) (andmap (lambda (part) (control-expression? part known)) (node-children value))]
        [else #f]))
    (define (expand-path known path)
      (let loop ([prefix '()] [remaining path])
        (cond
          [(null? remaining) (list prefix)]
          [(and (pair? (car remaining)) (eq? (caar remaining) 'index))
           (define name (cadar remaining))
           (unless (hash-has-key? controls name)
             (read-error source (node-at stage)
                         (format "unknown stage list position ~a" name)))
           (append*
            (for/list ([(candidate _) (in-hash known)]
                       #:when (and (= (length candidate) (add1 (length prefix)))
                                   (equal? prefix (take candidate (length prefix)))
                                   (exact-positive-integer? (last candidate))))
              (loop candidate (cdr remaining))))]
          [else (loop (append prefix (list (car remaining)))
                      (cdr remaining))])))
    (define (list-count-path? known path)
      (and (pair? path) (eq? (last path) 'count)
           (hash-has-key? known (drop-right path 1))
           (let ([value (hash-ref known (drop-right path 1))])
             (define descriptor
               (if (eq? value #t)
                   (hash-ref entry-paths (drop-right path 1)
                             (lambda () (hash-ref exit-paths (drop-right path 1) #t)))
                   value))
             (let countable? ([value descriptor])
               (match (ungroup-expression value)
                 [`(list ,_) #t]
                 [`(range ,_) #t]
                 [`(uncertain ,base ,_) (countable? base)]
                 [`(literal unknown) #t]
                 [#t #t]
                 [_ #f])))))
    (define (check-count-write known path at)
      (when (for*/or ([candidate (in-list (expand-path known path))]
                     [size (in-range 1 (add1 (length candidate)))])
              (list-count-path? known (take candidate size)))
        (read-error source at "the list property .count is read only")))
    (define (declared-path? known path)
      (define candidates (expand-path known path))
      (and (pair? candidates)
           (andmap (lambda (candidate) (or (hash-has-key? known candidate)
                                          (list-count-path? known candidate)))
                   candidates)))
    (define (check-state-reads value known)
      (define path (state-path value))
      (if path
          (unless (declared-path? known path)
            (read-error source (node-at value)
                        "resource write reads an unavailable state location"))
          (for ([part (in-list (node-children value))])
            (check-state-reads part known))))
    (define (validate-body forms available)
      (for/fold ([known available]) ([form (in-list forms)])
        (case (node-kind form)
          [(state-call)
           (define performer (or (third (node-value form)) default-performer))
           (unless performer
             (read-error source (node-at form)
                         "state-changing call needs a performer, on the call or stage"))
           (check-performer performer (node-at form))
           (define name (call-name form))
           (define definition (hash-ref definitions name #f))
           (unless definition
             (read-error source (node-at form)
                         (format "unknown procedure ~a" name)))
           (define expected (procedure-inputs definition))
           (define actual (map node-value (node-children form)))
           (unless (and (= (length expected) (length actual))
                        (andmap (lambda (input) (memq input actual)) expected))
             (read-error source (node-at form)
                         (format "input mappings for ~a must match its declared inputs" name)))
           (for ([mapping (in-list (node-children form))])
             (define path (node-value (car (node-children mapping))))
             (unless (declared-path? known path)
               (read-error source (node-at mapping)
                           (format "input location ~a is not available"
                                   (string-join (map (lambda (part) (format "~a" part)) path) ".")))))
           (unless (always-outputs? (node-children definition))
             (read-error source (node-at form)
                         (format "procedure ~a may finish without output" name)))
           (define target (node-value (second (node-value form))))
           (check-count-write known target (node-at form))
           (unless (declared-path? known (drop-right target 1))
             (read-error source (node-at form)
                         "return location needs an existing parent in state"))
           (when (or (exact-positive-integer? (last target))
                     (and (pair? (last target))
                          (eq? (car (last target)) 'index)))
             (unless (declared-path? known target)
               (read-error source (node-at form)
                           "return list position must exist in state")))
           (define dynamic-at
             (for/first ([part (in-list target)] [i (in-naturals)]
                         #:when (and (pair? part) (eq? (car part) 'index)))
               i))
           (define tracked-target (if dynamic-at (take target dynamic-at) target))
           (when dynamic-at (expand-path known target))
           (hash-set! written tracked-target #t)
           (define next (hash-copy known))
           (hash-set! next tracked-target #t)
           next]
          [(call)
           (read-error source (node-at form)
                       "calls inside a state stage need with locations and into a return location")]
          [(state-stage stage)
           (read-error source (node-at form)
                       "a state stage cannot be nested inside another state stage")]
          [(output)
           (read-error source (node-at form)
                       "output cannot leave a state stage before end stage")]
          [(assignment)
           (define name (car (node-value form)))
           (unless (and (not (memq name '(information environment factors)))
                        (control-expression? (cdr (node-value form)) known))
             (read-error source (node-at form)
                         "local names in a state stage are only for integer counters or positions"))
           (hash-set! controls name #t)
           known]
          [(path-assignment)
           (define target (first (node-children form)))
           (define expression (second (node-children form)))
           (define target-path (state-path target))
           (when target-path (check-count-write known target-path (node-at form)))
           (check-state-reads expression known)
           (cond
             [(and (resource-path? target) (not target-path)) known]
             [(and target-path (resource-path? expression)
                   (>= (length target-path) 2))
              (unless (declared-path? known (drop-right target-path 1))
                (read-error source (node-at form)
                            "resource read needs an existing parent in state"))
              (when (or (exact-positive-integer? (last target-path))
                        (and (pair? (last target-path))
                             (eq? (car (last target-path)) 'index)))
                (unless (declared-path? known target-path)
                  (read-error source (node-at form)
                              "resource read list position must exist in state")))
              (define dynamic-at
                (for/first ([part (in-list target-path)] [i (in-naturals)]
                            #:when (and (pair? part) (eq? (car part) 'index)))
                  i))
              (define tracked-target
                (if dynamic-at (take target-path dynamic-at) target-path))
              (hash-set! written tracked-target #t)
              (define next (hash-copy known))
              (hash-set! next tracked-target #t)
              next]
             [else
              (read-error source (node-at form)
                          "state assignment needs a resource read or resource write")])]
          [(sequence)
           (validate-body (node-children form) known)]
          [(if)
           (define branches (node-children form))
           (define outcomes
             (for/list ([branch (in-list branches)])
               (validate-body (node-children branch) (hash-copy known))))
           (define candidates
             (if (and (pair? branches) (not (node-value (last branches))))
                 outcomes
                 (cons known outcomes)))
           (for/hash ([(path _) (in-hash (car candidates))]
                      #:when (andmap (lambda (outcome)
                                      (hash-has-key? outcome path))
                                    (cdr candidates)))
             (values path #t))]
          [(for-each)
           (unless (control-collection? (cdr (node-value form)) known)
             (read-error source (node-at form)
                         "for each in a state stage needs integer positions"))
           (define name (car (node-value form)))
           (define previously? (hash-has-key? controls name))
           (hash-set! controls name #t)
           (define after (validate-body (node-children form) (hash-copy known)))
           (unless previously? (hash-remove! controls name))
           known]
          [(repeat repeat-until while)
           (define after (validate-body (node-children form) (hash-copy known)))
           (if (or (eq? (node-kind form) 'repeat-until)
                   (and (eq? (node-kind form) 'repeat)
                        (eq? (node-kind (ungroup-node (node-value form))) 'literal)
                        (exact-positive-integer? (node-value (ungroup-node (node-value form))))))
               after
               known)]
          [else known])))
    (define available (validate-body (node-children stage) entry-paths))
    (for ([(path _) (in-hash available)])
      (unless (hash-has-key? exit-paths path)
        (read-error source (node-at stage)
                    (format "closing state omits ~a"
                            (string-join (map (lambda (part) (format "~a" part)) path) ".")))))
    (for ([(path _) (in-hash exit-paths)])
      (unless (or (hash-has-key? available path)
                  (for/or ([(target _) (in-hash written)])
                    (and (hash-has-key? available target)
                         (<= (length target) (length path))
                         (equal? target (take path (length target))))))
        (read-error source (node-at stage)
                    (format "closing state adds ~a without a return location"
                            (string-join (map (lambda (part) (format "~a" part)) path) ".")))))
    (define (prefix? first second)
      (and (<= (length first) (length second))
           (equal? first (take second (length first)))))
    (for ([(path before) (in-hash entry-paths)])
      (define affected?
        (for/or ([(target _) (in-hash written)])
          (and (hash-has-key? available target)
               (or (prefix? path target) (prefix? target path)))))
      (when (and (hash-has-key? exit-paths path)
                 (not affected?)
                 (not (expression-equivalent? before (hash-ref exit-paths path))))
        (read-error source (node-at stage)
                    (format "closing state changes ~a without a return location"
                            (string-join (map (lambda (part) (format "~a" part)) path) "."))))))
  (define in-state-stage? (make-parameter #f))
  (define (check-forms forms inputs results [settable '()])
    (define writable settable)
    (for/fold ([visible results]) ([form (in-list forms)])
      (case (node-kind form)
        [(to import interface performer resource proposition implements must-call must-stage-order stage about
             included-file) visible]
        [(state-stage)
         (check-value (second (node-value form)) inputs visible)
         (check-value (third (node-value form)) inputs visible)
         (check-state-stage form)
         (parameterize ([in-state-stage? #t])
           (check-forms (node-children form) inputs
                        (append '(information environment factors) visible) writable))
         visible]
        [(state-call)
         (unless (in-state-stage?)
           (read-error source (node-at form)
                       "a call with state locations belongs inside a state stage"))
         visible]
        [(implement)
         (define subject (car (node-children form)))
         (define procedure-subject?
           (and (eq? (node-kind subject) 'result)
                (hash-has-key? definitions (node-value subject))
                (not (memq (node-value subject) visible))))
         (case (node-kind subject)
           [(stage-reference)
            (unless (hash-has-key? stage-names (node-value subject))
              (read-error source (node-at subject)
                          (format "unknown stage ~a in implement mapping" (node-value subject))))
            (define name (string->symbol (node-value subject)))
            (define root (string->symbol (car (string-split (node-value subject) "."))))
            (when (or (hash-has-key? definitions name)
                      (hash-has-key? interfaces name)
                      (hash-has-key? performers name)
                      (hash-has-key? resources name)
                      (memq root visible))
              (read-error source (node-at subject)
                          (format "ambiguous implementation target ~a: names a stage and another visible value or definition"
                                  (node-value subject))))]
           [else
            (unless procedure-subject?
              (check-value subject inputs visible))])
         (define reference (node-value form))
         (when (and (string? reference)
                    (or procedure-subject? (eq? (node-kind subject) 'stage-reference)))
           (read-error source (node-at form)
                       "stage and procedure mappings need a named interface or requirement"))
         (when (and (symbol? reference)
                    (not (resolve-interface-target resolved-interfaces reference)))
           (read-error source (node-at form)
                       (format "unknown interface or requirement ~a in implement mapping" reference)))
         visible]
        [(sequence)
         (check-forms (node-children form) inputs visible writable)
         visible]
        [(repeat)
         (check-value (node-value form) inputs visible)
         (check-forms (node-children form) inputs visible writable)
         visible]
        [(while)
         (check-value (node-value form) inputs visible)
         (check-forms (node-children form) inputs visible writable)
         visible]
        [(repeat-until)
         (define after-body (check-forms (node-children form) inputs visible writable))
         (check-value (node-value form) inputs after-body)
         visible]
        [(if)
         (for ([branch (in-list (node-children form))])
           (define condition (node-value branch))
           (when condition (check-value condition inputs visible))
           (check-forms (node-children branch) inputs visible writable))
         visible]
        [(for-each)
         (define name (car (node-value form)))
         (check-value (cdr (node-value form)) inputs visible)
         (when (or (hash-has-key? interfaces name)
                   (hash-has-key? resources name)
                   (memq name '(hypotheses assumptions conclusions))
                   (memq name inputs) (memq name visible))
           (read-error source (node-at form)
                       (format "loop variable ~a shadows a visible name" name)))
         (check-forms (node-children form) inputs (cons name visible) writable)
         visible]
        [(assignment)
         (define name (car (node-value form)))
         (define expression (cdr (node-value form)))
         (check-value expression inputs visible)
         (define root-append?
           (and (memq name '(hypotheses assumptions conclusions))
                (eq? (node-kind expression) 'augment)
                (eq? (node-kind (ungroup-node (second (node-children expression))))
                     'proposition-value)))
         (when (and (not root-append?)
                    (or (hash-has-key? interfaces name)
                   (hash-has-key? performers name)
                   (hash-has-key? resources name)
                   (memq name '(hypotheses assumptions conclusions))
                   (memq name inputs)
                   (and (memq name visible) (not (memq name writable)))))
           (read-error source (node-at form)
                       (format "cannot assign protected name ~a" name)))
         (unless (or root-append? (memq name writable))
           (set! writable (cons name writable)))
         (if (or root-append? (memq name visible))
             visible (cons name visible))]
        [(path-assignment path-update-command)
         (define target (car (node-children form)))
         (define (root value)
           (if (eq? (node-kind value) 'result)
               (node-value value)
               (root (car (node-children value)))))
         (define name (root target))
         (define resource-target? (hash-has-key? resources name))
         (define proposition-target?
           (memq name '(hypotheses assumptions conclusions)))
         (define state-target?
           (and (in-state-stage?)
                (memq name '(information environment factors))))
         (unless (or (and resource-target? (eq? (node-kind form) 'path-assignment)
                          (resource-path? target))
                     (and proposition-target? (eq? (node-kind form) 'path-assignment))
                     (and state-target? (eq? (node-kind form) 'path-assignment))
                     (and (memq name visible) (memq name writable)))
           (read-error source (node-at form)
                       (format "cannot update protected or unknown name ~a" name)))
         (unless (or resource-target? state-target? proposition-target?)
           (check-value target inputs visible))
         (when (eq? (node-kind form) 'path-assignment)
           (check-value (second (node-children form)) inputs visible))
         visible]
        [(print output)
         (check-value (node-value form) inputs visible)
         visible]
        [(call)
         (define name (call-name form))
         (define definition (hash-ref definitions name #f))
         (unless definition
           (read-error source (node-at form) (format "unknown procedure ~a" name)))
         (unless (= (length (node-children form))
                    (length (procedure-inputs definition)))
           (read-error source (node-at form)
                       (format "wrong number of inputs for ~a" name)))
         (for ([argument (in-list (node-children form))])
           (check-value argument inputs visible))
         (define result-name (cdr (node-value form)))
         (when result-name
           (unless (has-output? (node-children definition))
             (read-error source (node-at form)
                         (format "procedure ~a has no output" name)))
           (when (or (hash-has-key? interfaces result-name)
                     (hash-has-key? resources result-name)
                     (memq result-name '(hypotheses assumptions conclusions))
                     (memq result-name inputs) (memq result-name visible))
             (read-error source (node-at form)
                         (format "duplicate result ~a" result-name))))
         (if result-name (cons result-name visible) visible)])))
  (check-forms (node-children program) '() '())
  (define seen-top-level-additions (make-hash))
  (define (written-path value)
    (case (node-kind value)
      [(result) (list (node-value value))]
      [(field-ref)
       (define parent (written-path (first (node-children value))))
       (and parent (append parent (list (node-value value))))]
      [else #f]))
  (for ([form (in-list (node-children program))])
    (define-values (target expression)
      (case (node-kind form)
        [(assignment)
         (values (node 'result (car (node-value form)) '() (node-at form))
                 (cdr (node-value form)))]
        [(path-assignment)
         (values (first (node-children form))
                 (second (node-children form)))]
        [else (values #f #f)]))
    (when (and target expression
               (eq? (node-kind expression) 'augment))
      (define child (ungroup-node (second (node-children expression))))
      (define parent-path (written-path target))
      (when (and parent-path (eq? (node-kind child) 'proposition-value))
        (define key (append parent-path (node-value child)))
        (when (hash-has-key? seen-top-level-additions key)
          (read-error source (node-at form)
                      (format "duplicate ~a ~a at ~a"
                              (first (node-value child))
                              (second (node-value child))
                              (string-join (map symbol->string parent-path) "."))))
        (hash-set! seen-top-level-additions key #t))))
  (for ([declaration (in-hash-values performers)])
    (check-value (first (node-children declaration)) '() '()))
  (for ([declaration (in-hash-values resources)])
    (check-value (first (node-children declaration)) '() '()))
  (for ([declaration (in-hash-values propositions)])
    (check-value (first (node-children declaration)) '() '()))
  (for ([form (in-list (node-children program))]
        #:when (eq? (node-kind form) 'must-call))
    (define name (node-value form))
    (when (regexp-match? #rx"[.].*[.]" (symbol->string name))
      (read-error source (node-at form)
                  "a library dependency is private; import it directly to name it"))
    (unless (hash-has-key? definitions name)
      (read-error source (node-at form)
                  (format "unknown procedure ~a in must do" name))))
  (for ([definition (in-hash-values definitions)])
    (check-forms (node-children definition)
                 (procedure-inputs definition) '()))
  (define visited (make-hasheq))
  (define active (make-hasheq))
  (define (visit name)
    (hash-set! active name #t)
    (for ([call (in-list (calls-in (node-children (hash-ref definitions name))))])
      (define target (call-name call))
      (when (hash-ref active target #f)
        (read-error source (node-at call)
                    (format "recursive call to ~a is not supported in the first slice"
                            target)))
      (unless (hash-ref visited target #f) (visit target)))
    (hash-remove! active name)
    (hash-set! visited name #t))
  (for ([name (in-hash-keys definitions)])
    (unless (hash-ref visited name #f) (visit name))))

(define (node->datum form)
  (case (node-kind form)
    [(group) (list 'group (node->datum (car (node-children form))))]
    [(workflow library fragment workflow-fragment interface)
     (list (node-kind form) (node-value form)
           (map node->datum (node-children form)))]
    [(import) (cons 'import (node-value form))]
    [(include) (list 'include (node-value form))]
    [(included-file) (cons 'included-file (node-value form))]
    [(implements)
     (list 'implements (node-value form) (map node->datum (node-children form)))]
    [(provide affects) (cons (node-kind form) (node-value form))]
    [(version extends) (list (node-kind form) (node-value form))]
    [(interface-field required-interface-field)
     (define child (and (pair? (node-children form)) (car (node-children form))))
     (define constrained? (and child (eq? (node-kind child) 'field-constraint)))
     (append
      (list 'interface-field (node-value form)
            (and child (not constrained?) (node->datum child))
            (eq? (node-kind form) 'required-interface-field) #f)
      (if constrained? (list (node->datum child)) '()))]
    [(field-constraint) (node->datum (car (node-children form)))]
    [(interface-group required-interface-group)
     (list 'interface-field (node-value form) #f
           (eq? (node-kind form) 'required-interface-group)
           (map node->datum (node-children form)))]
    [(interface-if)
     (list 'interface-if (map node->datum (node-children form)))]
    [(interface-branch)
     (list 'interface-branch
           (and (node-value form) (node->datum (node-value form)))
           (map node->datum (node-children form)))]
    [(interface-requirement)
     (list 'interface-requirement (node->datum (node-value form)))]
    [(interface-for-each)
     (list 'interface-for-each (car (node-value form))
           (node->datum (cdr (node-value form)))
           (map node->datum (node-children form)))]
    [(must-call) (list 'must-call (node-value form))]
    [(implement)
     (list 'implement (node->datum (car (node-children form))) (node-value form))]
    [(stage-reference) (list 'stage-reference (node-value form))]
    [(must-stage-order) (list 'must-stage-order (node-value form))]
    [(about) (list 'about (node-value form))]
    [(stage) (append (list 'stage (node-value form))
                     (map node->datum (node-children form)))]
    [(performer)
     (list 'performer (node-value form)
           (node->datum (first (node-children form))))]
    [(resource)
     (list 'resource (node-value form)
           (node->datum (first (node-children form))))]
    [(proposition)
     (list 'proposition (node-value form)
           (node->datum (first (node-children form))))]
    [(proposition-value)
     (list 'proposition-value (node-value form)
           (node->datum (first (node-children form))))]
    [(uncertain)
     (list 'uncertain
           (node->datum (first (node-children form)))
           (node->datum (second (node-children form))))]
    [(state-stage)
     (list 'state-stage (car (node-value form))
           (node->datum (second (node-value form)))
           (map node->datum (node-children form))
           (node->datum (third (node-value form)))
           (fourth (node-value form)))]
    [(to) (list 'to (procedure-name form) (procedure-inputs form)
                (map node->datum (node-children form)))]
    [(call) (list 'call (call-name form) (map node->datum (node-children form))
                  (cdr (node-value form)))]
    [(state-call)
     (list 'state-call (call-name form)
           (for/list ([mapping (in-list (node-children form))])
             (list (node-value mapping)
                   (node-value (car (node-children mapping)))))
           (node-value (second (node-value form)))
           (third (node-value form))
           (state-call-location-syntax form))]
    [(location)
     (list 'location (node-value form)
           (node->datum (car (node-children form))))]
    [(sequence) (list 'sequence (map node->datum (node-children form)))]
    [(repeat) (list 'repeat (node->datum (node-value form))
                    (map node->datum (node-children form)))]
    [(repeat-until while)
     (list (node-kind form) (node->datum (node-value form))
           (map node->datum (node-children form)))]
    [(if) (list 'if (map node->datum (node-children form)))]
    [(branch) (list 'branch (and (node-value form)
                                (node->datum (node-value form)))
                    (map node->datum (node-children form)))]
    [(for-each) (list 'for-each (car (node-value form))
                      (node->datum (cdr (node-value form)))
                      (map node->datum (node-children form)))]
    [(assignment) (list 'assignment (car (node-value form))
                 (node->datum (cdr (node-value form))))]
    [(path-assignment)
     (list 'path-assignment
           (node->datum (first (node-children form)))
           (node->datum (second (node-children form))))]
    [(path-update-command)
     (list 'path-update-command
           (node->datum (first (node-children form))))]
    [(print output) (list (node-kind form) (node->datum (node-value form)))]
    [(list range) (list (node-kind form) (map node->datum (node-children form)))]
    [(fields)
     (list 'fields
           (for/list ([field (in-list (node-children form))])
             (list (node-value field)
                   (node->datum (car (node-children field))))))]
    [(field-ref)
     (list 'field-ref (node-value form)
           (node->datum (car (node-children form))))]
    [(dot-select dot-update)
     (list (node-kind form) (map node->datum (node-children form)))]
    [(compare kind-test typed-default binary unary augment)
     (list (node-kind form) (node-value form)
           (map node->datum (node-children form)))]
    [(literal parameter result) (list (node-kind form) (node-value form))]))

;; Keep source expressions beside resolved location paths: an index such as
;; [(position)] must retain its group even though its resolved path is unchanged.
(define (state-call-location-syntax form)
  (list 'locations
        (for/list ([mapping (in-list (node-children form))])
          (list (node-value mapping)
                (node->datum (car (node-children mapping)))))
        (node->datum (second (node-value form)))))

(define (parse-sciencelogo-tree-file path)
  (define full (path->complete-path path))
  (call-with-input-file full
    (lambda (in)
      (port-count-lines! in)
      (define first-line (read-line in 'any))
      (unless (and (string? first-line)
                   (string=? (string-trim first-line) "#lang sciencelogo"))
        (error 'parse-sciencelogo-tree-file "expected #lang sciencelogo in ~a" full))
      (parse-tree in (path->string full)))))

(define (parse-sciencelogo-file path)
  (node->datum (parse-sciencelogo-tree-file path)))

(define (sciencelogo-read in)
  (list (list 'run-program (list 'quote (parse-program in (object-name in))))))

(define (sciencelogo-read-syntax source in)
  (list (datum->syntax #f
                       (list 'run-program (list 'quote (parse-program in source)))
                       (list source #f #f #f #f))))
