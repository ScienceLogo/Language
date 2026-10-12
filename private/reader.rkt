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
         "record-interfaces.rkt")

(provide sciencelogo-read
         sciencelogo-read-syntax
         parse-sciencelogo-file
         parse-sciencelogo-tree-file
         node->datum
         (struct-out token)
         (struct-out node))

(struct token (kind value line column position source) #:transparent)
(struct node (kind value children at) #:transparent)

(define (read-error source at message)
  (raise-read-error message (token-source at) (token-line at) (token-column at)
                    (token-position at) 1))

(define (lex in source)
  (port-count-lines! in)
  (define (at kind value)
    (define-values (line column position) (port-next-location in))
    (token kind value line column position source))
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
  (define tokens (list->vector (lex in source)))
  (define index 0)
  (define commands '("to" "do" "stage" "print" "output" "include" "implements" "must" "workflow" "interface" "repeat" "for" "while" "if" "else" "set"))
  (define reserved
    (append commands '("as" "at" "import" "workflow" "library"
                       "interface" "version" "require" "affects" "provide" "by"
                       "each" "in" "until" "range" "step" "true" "false"
                       "unknown" "=" "!=" "<" "<=" ">" ">="
                       "+" "-" "*" "/" "and" "or" "not" "xor" "of" "but" "implement"
                       "extends")))
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
  (define (named-word description)
    (define found (expect 'word description))
    (define text (token-value found))
    (when (or (member text reserved)
              (and (positive? (string-length text))
                   (char=? (string-ref text 0) #\:)))
      (read-error source found (format "expected ~a" description)))
    (string->symbol text))
  (define comparisons '("=" "!=" "<" "<=" ">" ">="))
  (define (valid-inline-interface-name? name)
    (and (not (string=? name ""))
         (not (regexp-match? #px"[\\s\\[\\]();\"#]" name))
         (not (regexp-match? #px"^:" name))
         (not (regexp-match? #rx"[.]" name))
         (not (regexp-match? #px"^[+-]?[0-9]" name))
         (not (member name reserved))))
  (define (operator-precedence name)
    (cond [(string=? name "of") 80]
          [(string=? name "but") 75]
          [(member name '("*" "/")) 60]
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
            (when (and (= operator 40) (eq? (node-kind left) 'compare))
              (read-error source found "comparison cannot be chained; use and"))
            (when (and (= operator 80) (not (eq? (node-kind left) 'result)))
              (read-error source found "expected a field name before of"))
            (advance!)
            (let ([right (if (= operator 75)
                             (let ([value (parse-atom stop-word)])
                               (unless (or (eq? (node-kind value) 'fields)
                                           (and (eq? (node-kind value) 'list)
                                                (null? (node-children value))))
                                 (read-error source found
                                             "but needs named fields in [name = value] or []"))
                               (if (eq? (node-kind value) 'fields)
                                   value
                                   (struct-copy node value [kind 'fields])))
                             (parse-value (if (= operator 80)
                                              operator
                                              (add1 operator))
                                          stop-word))])
              (loop (cond
                      [(= operator 80)
                       (node 'field-ref (node-value left) (list right) found)]
                      [(= operator 75)
                       (node 'but #f (list left right) found)]
                      [else
                       (node (if (= operator 40) 'compare 'binary)
                             (string->symbol (token-value found))
                             (list left right) found)]))))
          left)))
  (define (parse-atom [stop-word #f])
    (define found (current))
    (case (token-kind found)
      [(left-paren)
       (advance!)
       (define value (parse-value))
       (expect 'right-paren ") after grouped expression")
       value]
      [(open)
       (advance!)
       (define fields?
         (and (eq? (token-kind (current)) 'word)
              (< (add1 index) (vector-length tokens))
              (let ([next (vector-ref tokens (add1 index))])
                (and (eq? (token-kind next) 'word)
                     (string=? (token-value next) "=")))))
       (if fields?
           (node 'fields #f
                 (let loop ([backward '()] [seen '()])
                   (case (token-kind (current))
                     [(close) (advance!) (reverse backward)]
                     [(eof) (read-error source (current) "expected ] after named fields")]
                     [else
                      (define field-at (current))
                      (define name (named-word "a field name"))
                      (when (memq name seen)
                        (read-error source field-at
                                    (format "duplicate field ~a" name)))
                      (expect-word "=")
                      (define value (parse-value))
                      (loop (cons (node 'field-entry name (list value) field-at)
                                  backward)
                            (cons name seen))]))
                 found)
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
         [(string=? text "item")
          (define saved index)
          (define position
            (with-handlers ([exn:fail:read? (lambda (_) #f)])
              (parse-value 0 "of")))
          (if (and position
                   (eq? (token-kind (current)) 'word)
                   (string=? (token-value (current)) "of"))
              (begin
                (advance!)
                (node 'item-ref #f (list position (parse-value 80)) found))
              (begin
                (set! index saved)
                (node 'result 'item '() found)))]
         [(string=? text "range")
          (define start (parse-value))
          (expect-word "to")
          (define end (parse-value))
          (expect-word "step")
          (node 'range #f (list start end (parse-value)) found)]
         [(member text '("true" "false" "unknown"))
          (node 'literal (cond [(string=? text "unknown") 'unknown]
                               [else (string=? text "true")]) '() found)]
         [(regexp-match? #px"^[+-]?[0-9]+(?:[.][0-9]+)?$" text)
          (node 'literal (string->number (string-append "#e" text)) '() found)]
         [(and (> (string-length text) 1) (char=? (string-ref text 0) #\:))
          (node 'parameter (string->symbol (substring text 1)) '() found)]
         [(or (member text reserved)
              (string=? text ":"))
          (read-error source found "expected a value")]
         [else (node 'result (string->symbol text) '() found)])]
      [else (read-error source found "expected a value")]))
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
             (member (token-value found) commands))))
  (define (parse-import start)
    (define url (token-value (expect 'string "a quoted Git repository URL")))
    (expect-word "at")
    (define revision (token-value (expect 'string "a quoted tag or commit")))
    (expect-word "as")
    (define alias (named-word "an import alias"))
    (when (regexp-match? #rx"[.]" (symbol->string alias))
      (read-error source start "an import alias cannot contain a dot"))
    (node 'import (list url revision alias) '() start))
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
    (define command (expect 'word "a command"))
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
                 (loop (cons input backward))))))
       (expect 'open "[ after procedure inputs")
       (node 'to (cons name inputs) (parse-body #f #t #f #f) command)]
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
       (define name (token-value (expect 'string "a quoted interface name")))
       (unless (valid-inline-interface-name? name)
         (read-error source command
                     "an inline interface needs a name usable as a value"))
       (expect 'open "[ after the interface name")
       (define declaration (node 'interface name (parse-interface-body) command))
       (validate-interface declaration source)
       (when (for/or ([part (in-list (node-children declaration))])
               (eq? (node-kind part) 'require))
         (read-error source command
                     "inline interfaces describe records; put workflow-part interfaces in a separate file"))
       declaration]
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
                 (define name (token-value (expect 'string "a quoted stage name")))
                 (when (string=? name "")
                   (read-error source at "stage name cannot be empty"))
                 (when (member name backward)
                   (read-error source at (format "duplicate required stage ~s" name)))
                 (loop (cons name backward))])))
          (when (< (length names) 2)
            (read-error source command "must stages in order needs at least two stage names"))
          (node 'must-stage-order names '() command)]
         [_
          (define name (string->symbol (token-value form)))
          (when (member (token-value form) reserved)
            (read-error source form "expected a record name after must"))
          (expect-word "implement")
          (define reference
            (if (eq? (token-kind (current)) 'string)
                (let ([path (token-value (advance!))])
                  (when (or (string=? path "")
                            (not (relative-path? (string->path path))))
                    (read-error source form "interface file path must be relative"))
                  path)
                (named-word "an interface name or quoted relative path")))
          (node 'must-implement (list name reference) '() command)])]
      ["stage"
       (when (or includes-allowed? imports-allowed?)
         (read-error source command "stage belongs in a workflow or procedure"))
       (define name (token-value (expect 'string "a quoted stage name")))
       (when (string=? name "")
         (read-error source command "stage name cannot be empty"))
       (node 'stage name '() command)]
      ["do"
       (if (eq? (token-kind (current)) 'open)
           (begin
             (advance!)
             (node 'sequence #f (parse-body #f in-procedure? #f #f) command))
           (let ([name (named-word "a procedure name")])
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
             (node 'call (cons name result-name) arguments command)))]
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
       (expect-word "in")
       (define collection (parse-value))
       (expect 'open "[ after the collection")
       (node 'for-each (cons name collection)
             (parse-body #f in-procedure? #f #f) command)]
      ["set"
       (define name (named-word "a value name"))
       (expect-word "to")
       (node 'set (cons name (parse-value)) '() command)]
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
      [_ (read-error source command
                     (format "unsupported command ~a in the first ScienceLogo slice"
                             (token-value command)))]))
  (define (parse-interface-body)
    (let loop ([backward '()])
      (define found (current))
      (case (token-kind found)
        [(close) (advance!) (reverse backward)]
        [(eof) (read-error source found "expected ] before end of file")]
        [else
         (define command (expect 'word "an interface field, extends, version, require, or affects"))
         (define form
           (match (token-value command)
             ["extends"
              (node 'extends (named-word "a parent interface name") '() command)]
             ["version"
              (node 'version (token-value (expect 'string "a quoted interface version"))
                    '() command)]
             ["require"
              (node 'require (named-word "a required part name") '() command)]
             ["affects"
              (node 'affects
                    (list (named-word "a source part name")
                          (named-word "an affected part name"))
                    '() command)]
             [field-name
              (when (or (member field-name reserved)
                        (regexp-match? #px"^[+-]?[0-9]" field-name))
                (read-error source command "expected an interface field name"))
              (define default
                (and (eq? (token-kind (current)) 'word)
                     (string=? (token-value (current)) "=")
                     (begin (advance!) (parse-value))))
              (node 'interface-field (string->symbol field-name)
                    (if default (list default) '()) command)]))
         (loop (cons form backward))])))
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
       (define imports
         (let loop ([backward '()])
           (if (and (eq? (token-kind (current)) 'word)
                    (string=? (token-value (current)) "import"))
               (loop (cons (parse-import (advance!)) backward))
               (reverse backward))))
       (values leading-title imports (parse-to-eof #t #f))]
      [(string=? kind "fragment")
       (values #f '() (parse-to-eof #t #t))]
      [(string=? kind "workflow-fragment")
       (values #f '() (parse-to-eof #t #f))]
      [else
       (advance!)
       (define title (token-value (expect 'string "a quoted library or interface name")))
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
          (unless (valid-inline-interface-name? title)
            (read-error source start
                        "an inline interface needs a name usable as a value"))
          (validate-interface declaration source)
          (when (for/or ([part (in-list forms)])
                  (eq? (node-kind part) 'require))
            (read-error source start
                        "inline interfaces describe records; put workflow-part interfaces in a separate file"))
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
  (cond
    [(memq (node-kind result) '(fragment workflow-fragment)) result]
    [(eq? (node-kind result) 'interface)
     (validate-interface result source)
     (for ([form (in-list (node-children result))]
           #:when (eq? (node-kind form) 'extends))
       (read-error source (node-at form)
                   "standalone interfaces cannot extend a local interface"))
     result]
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
     (check-direct-calls (node-children expanded) source)
     (define local-imports
       (filter (lambda (form) (eq? (node-kind form) 'import))
               (node-children expanded)))
     (define checked
       (struct-copy node expanded
                    [children (append (resolve-imports local-imports)
                                      (filter (lambda (form)
                                                (not (eq? (node-kind form) 'import)))
                                              (node-children expanded)))]))
     (validate-program checked source)
     checked]
    [else
     (when (eq? (node-kind result) 'workflow)
       (check-direct-calls workflow-forms source))
     (validate-program result source)
     result]))

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

(define (qualify-library-form form alias interface-names)
  (define (qualified name)
    (string->symbol (format "~a.~a" alias name)))
  (define (qualify-value value)
    (cond
      [(not (node? value)) value]
      [(and (eq? (node-kind value) 'result)
            (memq (node-value value) interface-names))
       (struct-copy node value [value (qualified (node-value value))])]
      [else
       (struct-copy node value
                    [children (map qualify-value (node-children value))])]))
  (define (qualify-form child)
    (qualify-library-form child alias interface-names))
  (case (node-kind form)
    [(interface)
     (struct-copy node form
                  [value (symbol->string (qualified (node-value form)))]
                  [children (map qualify-form (node-children form))])]
    [(extends)
     (struct-copy node form [value (qualified (node-value form))])]
    [(interface-field)
     (struct-copy node form
                  [children (map qualify-value (node-children form))])]
    [(stage)
     (struct-copy node form
                  [value (format "~a.~a" alias (node-value form))])]
    [(to)
     (struct-copy node form
                  [value (cons (qualified (procedure-name form))
                               (procedure-inputs form))]
                  [children (map qualify-form (node-children form))])]
    [(call)
     (struct-copy node form
                  [value (cons (qualified (call-name form))
                               (cdr (node-value form)))]
                  [children (map qualify-value (node-children form))])]
    [(set)
     (struct-copy node form
                  [value (cons (car (node-value form))
                               (qualify-value (cdr (node-value form))))])]
    [(print output)
     (struct-copy node form [value (qualify-value (node-value form))])]
    [(repeat repeat-until while)
     (struct-copy node form
                  [value (qualify-value (node-value form))]
                  [children (map qualify-form (node-children form))])]
    [(for-each)
     (struct-copy node form
                  [value (cons (car (node-value form))
                               (qualify-value (cdr (node-value form))))]
                  [children (map qualify-form (node-children form))])]
    [(branch)
     (struct-copy node form
                  [value (and (node-value form)
                              (qualify-value (node-value form)))]
                  [children (map qualify-form (node-children form))])]
    [(sequence if)
     (struct-copy node form
                  [children (map qualify-form (node-children form))])]
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
      (check-direct-calls (node-children expanded) source)
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
      (define local-definitions
        (map (lambda (form)
               (qualify-library-form form qualified-alias interface-names))
             (filter (lambda (form) (memq (node-kind form) '(to interface)))
                     (node-children expanded))))
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
      [(call) (cons form calls)]
      [(sequence repeat repeat-until for-each while if branch to)
       (append (calls-in (node-children form)) calls)]
      [else calls])))

(define (check-direct-calls forms source)
  (define (check-private-name name at)
    (when (and (symbol? name)
               (regexp-match? #rx"[.].*[.]" (symbol->string name)))
      (read-error source at
                  "a library dependency is private; import it directly to use it")))
  (for ([call (in-list (calls-in forms))])
    (when (regexp-match? #rx"[.].*[.]" (symbol->string (call-name call)))
      (read-error source (node-at call)
                  "a library dependency is private; import it directly to call it")))
  (define (check-form form)
    (when (memq (node-kind form) '(result extends))
      (check-private-name (node-value form) (node-at form)))
    (case (node-kind form)
      [(must-implement)
       (check-private-name (cadr (node-value form)) (node-at form))]
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
  (define parents (make-hasheq))
  (for ([form (in-list (node-children interface))]
        #:when (eq? (node-kind form) 'require))
    (define part (node-value form))
    (when (hash-has-key? required part)
      (read-error source (node-at form) (format "duplicate required part ~a" part)))
    (hash-set! required part #t))
  (for ([form (in-list (node-children interface))]
        #:when (eq? (node-kind form) 'interface-field))
    (define name (node-value form))
    (when (hash-has-key? fields name)
      (read-error source (node-at form) (format "duplicate interface field ~a" name)))
    (hash-set! fields name #t))
  (for ([form (in-list (node-children interface))]
        #:when (eq? (node-kind form) 'extends))
    (define parent (node-value form))
    (when (hash-has-key? parents parent)
      (read-error source (node-at form) (format "duplicate parent interface ~a" parent)))
    (hash-set! parents parent #t))
  (when (and (or (positive? (hash-count fields))
                 (positive? (hash-count parents)))
             (or (positive? (hash-count required))
                 (for/or ([form (in-list (node-children interface))])
                   (eq? (node-kind form) 'affects))))
    (read-error source (node-at interface)
                "record fields and workflow parts cannot share one interface"))
  (when (and (zero? (hash-count required)) (zero? (hash-count fields))
             (zero? (hash-count parents)))
    (read-error source (node-at interface)
                "an interface needs a field, parent, or required part"))
  (for ([form (in-list (node-children interface))]
        #:when (eq? (node-kind form) 'affects))
    (for ([part (in-list (node-value form))])
      (unless (hash-has-key? required part)
        (read-error source (node-at form)
                    (format "impact references unknown part ~a" part))))))

(define (validate-program program source)
  (define definitions (make-hasheq))
  (define interfaces (make-hasheq))
  (for ([form (in-list (node-children program))]
        #:when (eq? (node-kind form) 'interface))
    (define name (string->symbol (node-value form)))
    (when (hash-has-key? interfaces name)
      (read-error source (node-at form) (format "duplicate interface ~a" name)))
    (hash-set! interfaces name form))
  (resolve-record-interfaces
   (for/hasheq ([(name form) (in-hash interfaces)])
     (values name (map node->datum (node-children form))))
   (lambda (name message)
     (read-error source (node-at (hash-ref interfaces name)) message)))
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
  (define stage-names (make-hash))
  (define (check-stage-names forms)
    (for ([form (in-list forms)])
      (case (node-kind form)
        [(stage)
         (define name (node-value form))
         (when (hash-has-key? stage-names name)
           (read-error source (node-at form) (format "duplicate stage ~s" name)))
         (hash-set! stage-names name #t)]
        [(to sequence repeat repeat-until for-each while if branch)
         (check-stage-names (node-children form))]
        [else (void)])))
  (check-stage-names (node-children program))
  (define (check-value value inputs results)
    (case (node-kind value)
      [(list fields field-entry field-ref item-ref range compare binary unary but)
       (for ([part (in-list (node-children value))])
         (check-value part inputs results))]
      [(parameter)
       (unless (memq (node-value value) inputs)
         (read-error source (node-at value)
                     (format "unknown input :~a" (node-value value))))]
      [(result)
       (unless (or (memq (node-value value) results)
                   (hash-has-key? interfaces (node-value value)))
         (read-error source (node-at value)
                     (format "unknown result ~a" (node-value value))))]))
  (define (check-forms forms inputs results [settable '()])
    (define writable settable)
    (for/fold ([visible results]) ([form (in-list forms)])
      (case (node-kind form)
        [(to import interface implements must-call must-stage-order stage
             included-file) visible]
        [(must-implement)
         (define name (car (node-value form)))
         (unless (memq name visible)
           (read-error source (node-at form)
                       (format "unknown record ~a in must implement" name)))
         (define reference (cadr (node-value form)))
         (when (and (symbol? reference)
                    (not (hash-has-key? interfaces reference)))
           (read-error source (node-at form)
                       (format "unknown interface ~a in must implement" reference)))
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
                   (memq name inputs) (memq name visible))
           (read-error source (node-at form)
                       (format "loop variable ~a shadows a visible name" name)))
         (check-forms (node-children form) inputs (cons name visible) writable)
         visible]
        [(set)
         (define name (car (node-value form)))
         (check-value (cdr (node-value form)) inputs visible)
         (when (or (hash-has-key? interfaces name)
                   (memq name inputs)
                   (and (memq name visible) (not (memq name writable))))
           (read-error source (node-at form)
                       (format "cannot set protected name ~a" name)))
         (unless (memq name writable)
           (set! writable (cons name writable)))
         (if (memq name visible) visible (cons name visible))]
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
                     (memq result-name inputs) (memq result-name visible))
             (read-error source (node-at form)
                         (format "duplicate result ~a" result-name))))
         (if result-name (cons result-name visible) visible)])))
  (check-forms (node-children program) '() '())
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
    [(workflow library fragment workflow-fragment interface)
     (list (node-kind form) (node-value form)
           (map node->datum (node-children form)))]
    [(import) (cons 'import (node-value form))]
    [(include) (list 'include (node-value form))]
    [(included-file) (cons 'included-file (node-value form))]
    [(implements)
     (list 'implements (node-value form) (map node->datum (node-children form)))]
    [(provide affects) (cons (node-kind form) (node-value form))]
    [(version require extends) (list (node-kind form) (node-value form))]
    [(interface-field)
     (list 'interface-field (node-value form)
           (and (pair? (node-children form))
                (node->datum (car (node-children form)))))]
    [(must-call) (list 'must-call (node-value form))]
    [(must-implement) (cons 'must-implement (node-value form))]
    [(must-stage-order) (list 'must-stage-order (node-value form))]
    [(stage) (list 'stage (node-value form))]
    [(to) (list 'to (procedure-name form) (procedure-inputs form)
                (map node->datum (node-children form)))]
    [(call) (list 'call (call-name form) (map node->datum (node-children form))
                  (cdr (node-value form)))]
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
    [(set) (list 'set (car (node-value form))
                 (node->datum (cdr (node-value form))))]
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
    [(item-ref)
     (list 'item-ref
           (node->datum (first (node-children form)))
           (node->datum (second (node-children form))))]
    [(but)
     (list 'but
           (node->datum (first (node-children form)))
           (node->datum (second (node-children form))))]
    [(compare binary unary)
     (list (node-kind form) (node-value form)
           (map node->datum (node-children form)))]
    [(literal parameter result) (list (node-kind form) (node-value form))]))

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
