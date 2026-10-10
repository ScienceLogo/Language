#lang racket/base

(require racket/file
         racket/list
         racket/match
         racket/path
         racket/port
         racket/string
         racket/system
         syntax/readerr)

(provide sciencelogo-read
         sciencelogo-read-syntax
         parse-sciencelogo-file
         parse-sciencelogo-tree-file
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
         (not (memv c '(#\[ #\] #\; #\" #\#)))))
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
  (define commands '("to" "do" "stage" "print" "output" "include" "implements" "must" "workflow"))
  (define reserved
    (append commands '("as" "at" "import" "workflow" "library"
                       "interface" "version" "require" "affects" "provide" "by")))
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
  (define (parse-value)
    (define found (current))
    (case (token-kind found)
      [(string)
       (advance!)
       (node 'literal (token-value found) '() found)]
      [(word)
       (define text (token-value found))
       (advance!)
       (cond
         [(and (> (string-length text) 1) (char=? (string-ref text 0) #\:))
          (node 'parameter (string->symbol (substring text 1)) '() found)]
         [(or (member text reserved)
              (string=? text ":"))
          (read-error source found "expected a value")]
         [else (node 'result (string->symbol text) '() found)])]
      [else (read-error source found "expected a value")]))
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
       (unless includes-allowed?
         (read-error source command "include belongs directly in a library file"))
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
       (define form (expect 'word "do or stages after must"))
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
         [_ (read-error source form "expected do or stages after must")])]
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
         (define command (expect 'word "version, require, or affects"))
         (define form
           (match (token-value command)
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
             [_ (read-error source command
                            "an interface accepts only version, require, and affects")]))
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
      [(member first-word '("library" "interface")) first-word]
      [(or (equal? first-word "include")
           (and (equal? expected-kind "fragment")
                (member first-word '("to" "include"))))
       "fragment"]
      [else "workflow"]))
  (when (and expected-kind (not (string=? kind expected-kind)))
    (read-error source start (format "expected ~a declaration" expected-kind)))
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
      [else
       (advance!)
       (define title (token-value (expect 'string "a quoted library or interface name")))
       (expect 'open "[ after the library or interface name")
       (values title '()
               (if (string=? kind "interface")
                   (parse-interface-body)
                   (parse-body #t #f #t #t)))]))
  (unless (eq? (token-kind (current)) 'eof)
    (read-error source (current) "expected end of file after library or interface"))
  (when (member kind '("library" "fragment"))
    (for ([form (in-list forms)])
      (unless (memq (node-kind form) (if (string=? kind "library")
                                         '(to include import)
                                         '(to include)))
        (read-error source (node-at form)
                    "a library can contain only to, include, and import declarations"))))
  (define result
    (case (string->symbol kind)
      [(library) (node 'library title forms start)]
      [(interface) (node 'interface title forms start)]
      [(fragment) (node 'fragment #f forms start)]
      [(workflow) (node 'workflow title
                           (append (resolve-imports imports) forms) start)]))
  (cond
    [(eq? (node-kind result) 'fragment) result]
    [(eq? (node-kind result) 'interface)
     (validate-interface result source)
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
       (check-direct-calls forms source))
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
    (read-error source at "library source must begin with #lang sciencelogo"))
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

(define (qualify-library-form form alias)
  (define (qualified name)
    (string->symbol (format "~a.~a" alias name)))
  (case (node-kind form)
    [(stage)
     (struct-copy node form
                  [value (format "~a.~a" alias (node-value form))])]
    [(to)
     (struct-copy node form
                  [value (cons (qualified (procedure-name form))
                               (procedure-inputs form))]
                  [children (map (lambda (child) (qualify-library-form child alias))
                                 (node-children form))])]
    [(call)
     (struct-copy node form
                  [value (cons (qualified (call-name form))
                               (cdr (node-value form)))])]
    [(sequence)
     (struct-copy node form
                  [children (map (lambda (child) (qualify-library-form child alias))
                                 (node-children form))])]
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
      (define local-definitions
        (map (lambda (form) (qualify-library-form form qualified-alias))
             (filter (lambda (form) (eq? (node-kind form) 'to))
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
      [(sequence to) (append (calls-in (node-children form)) calls)]
      [else calls])))

(define (check-direct-calls forms source)
  (for ([call (in-list (calls-in forms))])
    (when (regexp-match? #rx"[.].*[.]" (symbol->string (call-name call)))
      (read-error source (node-at call)
                  "a library dependency is private; import it directly to call it"))))

(define (call-name call) (car (node-value call)))
(define (procedure-name definition) (car (node-value definition)))
(define (procedure-inputs definition) (cdr (node-value definition)))

(define (has-output? forms)
  (for/or ([form (in-list forms)])
    (or (eq? (node-kind form) 'output)
        (and (eq? (node-kind form) 'sequence)
             (has-output? (node-children form))))))

(define (validate-interface interface source)
  (define versions
    (filter (lambda (form) (eq? (node-kind form) 'version))
            (node-children interface)))
  (unless (= (length versions) 1)
    (read-error source (node-at interface)
                "an interface needs exactly one version declaration"))
  (when (string=? (node-value (car versions)) "")
    (read-error source (node-at (car versions)) "interface version cannot be empty"))
  (define required (make-hasheq))
  (for ([form (in-list (node-children interface))]
        #:when (eq? (node-kind form) 'require))
    (define part (node-value form))
    (when (hash-has-key? required part)
      (read-error source (node-at form) (format "duplicate required part ~a" part)))
    (hash-set! required part #t))
  (when (zero? (hash-count required))
    (read-error source (node-at interface)
                "an interface needs at least one required part"))
  (for ([form (in-list (node-children interface))]
        #:when (eq? (node-kind form) 'affects))
    (for ([part (in-list (node-value form))])
      (unless (hash-has-key? required part)
        (read-error source (node-at form)
                    (format "impact references unknown part ~a" part))))))

(define (validate-program program source)
  (define definitions (make-hasheq))
  (for ([form (in-list (node-children program))]
        #:when (eq? (node-kind form) 'to))
    (define name (procedure-name form))
    (when (hash-has-key? definitions name)
      (read-error source (node-at form) (format "duplicate procedure ~a" name)))
    (hash-set! definitions name form))
  (define stage-names (make-hash))
  (define (check-stage-names forms)
    (for ([form (in-list forms)])
      (case (node-kind form)
        [(stage)
         (define name (node-value form))
         (when (hash-has-key? stage-names name)
           (read-error source (node-at form) (format "duplicate stage ~s" name)))
         (hash-set! stage-names name #t)]
        [(to sequence) (check-stage-names (node-children form))]
        [else (void)])))
  (check-stage-names (node-children program))
  (define (check-value value inputs results)
    (case (node-kind value)
      [(parameter)
       (unless (memq (node-value value) inputs)
         (read-error source (node-at value)
                     (format "unknown input :~a" (node-value value))))]
      [(result)
       (unless (memq (node-value value) results)
         (read-error source (node-at value)
                     (format "unknown result ~a" (node-value value))))]))
  (define (check-forms forms inputs results)
    (for/fold ([visible results]) ([form (in-list forms)])
      (case (node-kind form)
        [(to import implements must-call must-stage-order stage) visible]
        [(sequence)
         (check-forms (node-children form) inputs visible)
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
           (when (or (memq result-name inputs) (memq result-name visible))
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
    [(workflow library fragment interface)
     (list (node-kind form) (node-value form)
           (map node->datum (node-children form)))]
    [(import) (cons 'import (node-value form))]
    [(include) (list 'include (node-value form))]
    [(implements)
     (list 'implements (node-value form) (map node->datum (node-children form)))]
    [(provide affects) (cons (node-kind form) (node-value form))]
    [(version require) (list (node-kind form) (node-value form))]
    [(must-call) (list 'must-call (node-value form))]
    [(must-stage-order) (list 'must-stage-order (node-value form))]
    [(stage) (list 'stage (node-value form))]
    [(to) (list 'to (procedure-name form) (procedure-inputs form)
                (map node->datum (node-children form)))]
    [(call) (list 'call (call-name form) (map node->datum (node-children form))
                  (cdr (node-value form)))]
    [(sequence) (list 'sequence (map node->datum (node-children form)))]
    [(print output) (list (node-kind form) (node->datum (node-value form)))]
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
