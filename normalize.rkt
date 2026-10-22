#lang racket/base

(require racket/list racket/match racket/port racket/string syntax/readerr)

(provide normalize-source normalized-source-origin
         (struct-out normalized-source) (struct-out source-origin))

;; Origins are indexed by output character, with one final entry for EOF.
(struct source-origin (source line column position span) #:transparent)
(struct normalized-source (text origins) #:transparent)
(struct bit (text kind offset exact?) #:transparent)
(struct item (token leading) #:transparent)
(struct bracket (open body close) #:transparent)
(struct expression (bits selector priority) #:transparent)
(struct selection (bits wrappers) #:transparent)

(define (normalized-source-origin result position)
  (unless (and (exact-positive-integer? position)
               (<= position (vector-length (normalized-source-origins result))))
    (raise-argument-error 'normalized-source-origin
                          "a one-based position in the normalized source, including EOF" position))
  (vector-ref (normalized-source-origins result) (sub1 position)))

(define (normalize-source text #:source [source #f]
                          #:line [first-line 1] #:column [first-column 0]
                          #:position [first-position 1])
  (unless (string? text) (raise-argument-error 'normalize-source "string?" text))
  (define length-in (string-length text))
  (define input (open-input-string text source))
  (port-count-lines! input)
  (set-port-next-location! input first-line first-column first-position)
  (define originals
    (let ([port (open-input-string text source)])
      (port-count-lines! port)
      (set-port-next-location! port first-line first-column first-position)
      (list->vector
       (let loop ([backward '()])
         (define-values (line column position) (port-next-location port))
         (define next (read-char port))
         (define at (source-origin source line column position (if (eof-object? next) 0 1)))
         (if (eof-object? next) (reverse (cons at backward))
             (loop (cons at backward)))))))
  (define (offset)
    (define-values (_line _column position) (port-next-location input))
    (- position first-position))
  (define (fail at message)
    (define origin (vector-ref originals (min length-in (max 0 at))))
    (raise-read-error message source (source-origin-line origin)
                      (source-origin-column origin) (source-origin-position origin) 1))
  (define (captured begin kind)
    (bit (substring text begin (offset)) kind begin #t))
  (define (word-character? c)
    (and (char? c) (not (char-whitespace? c))
         (not (memv c '(#\[ #\] #\( #\) #\; #\" #\#)))))
  (define (consume-block begin)
    (read-char input) (read-char input)
    (let loop ([depth 1])
      (define c (read-char input))
      (cond
        [(eof-object? c) (fail begin "unclosed #| comment")]
        [(and (eqv? c #\#) (eqv? (peek-char input) #\|))
         (read-char input) (loop (add1 depth))]
        [(and (eqv? c #\|) (eqv? (peek-char input) #\#))
         (read-char input) (unless (= depth 1) (loop (sub1 depth)))]
        [else (loop depth)])))
  (define header-match (regexp-match #px"^[ \t]*#lang sciencelogo[ \t]*(?:\r\n|\r|\n|$)" text))
  (define header
    (if header-match
        (let ([raw (car header-match)])
          (for ([c (in-string raw)]) (read-char input))
          (list (bit raw 'header 0 #t)))
        '()))
  (define flat
    (let loop ([backward '()] [leading '()])
      (define begin (offset))
      (define c (peek-char input))
      (cond
        [(eof-object? c)
         (reverse (cons (item (bit "" 'eof begin #t) (reverse leading)) backward))]
        [(char-whitespace? c)
         (let whitespace ()
           (when (and (char? (peek-char input)) (char-whitespace? (peek-char input)))
             (read-char input) (whitespace)))
         (loop backward (cons (captured begin 'trivia) leading))]
        [(eqv? c #\;)
         (let comment ()
           (define next (read-char input))
           (unless (or (eof-object? next) (eqv? next #\newline)) (comment)))
         (loop backward (cons (captured begin 'trivia) leading))]
        [(eqv? c #\#)
         (unless (eqv? (peek-char input 1) #\|) (fail begin "expected #| to start a block comment"))
         (consume-block begin)
         (loop backward (cons (captured begin 'trivia) leading))]
        [else
         (define kind
           (cond
             [(memv c '(#\[ #\] #\( #\))) (read-char input) 'delimiter]
             [(eqv? c #\") (read input) 'string]
             [else
              (let word ()
                (when (word-character? (peek-char input)) (read-char input) (word)))
              'word]))
         (loop (cons (item (captured begin kind) (reverse leading)) backward) '())])))
  (define (it-text unit)
    (and (item? unit) (bit-text (item-token unit))))
  (define (at unit)
    (bit-offset (item-token (if (bracket? unit) (bracket-open unit) unit))))
  (define (raw unit)
    (cond
      [(bracket? unit)
       (append (raw (bracket-open unit)) (append-map raw (bracket-body unit))
               (raw (bracket-close unit)))]
      [else (append (item-leading unit) (list (item-token unit)))]))
  (define (trivia unit)
    (item-leading (if (bracket? unit) (bracket-open unit) unit)))
  (define (replacement unit spelling)
    (append (trivia unit) (list (bit spelling 'word (at unit) #f))))
  (define (new spelling unit) (bit spelling 'word (at unit) #f))
  (define-values (forest end-item)
    (let ([remaining flat])
      (define (read-units [closing #f])
        (let loop ([backward '()])
          (define next (car remaining))
          (define spelling (it-text next))
          (cond
            [(equal? spelling "")
             (when closing (fail (at next) (format "expected ~a before end of file" closing)))
             (values (reverse backward) next)]
            [(member spelling '("]" ")"))
             (unless (equal? spelling closing) (fail (at next) "unmatched closing delimiter"))
             (set! remaining (cdr remaining))
             (values (reverse backward) next)]
            [(member spelling '("[" "("))
             (set! remaining (cdr remaining))
             (define-values (body close) (read-units (if (equal? spelling "[") "]" ")")))
             (loop (cons (bracket next body close) backward))]
            [else (set! remaining (cdr remaining)) (loop (cons next backward))])))
      (read-units)))
  (define changed? #f)
  (define (changed!) (set! changed? #t))
  (define command-words
    '("to" "do" "stage" "end" "print" "output" "include" "implements" "must"
      "workflow" "interface" "about" "performer" "resource" "hypothesis"
      "assumption" "conclusion" "repeat" "for" "while" "if" "else" "set"
      "import" "library"))
  (define (normalize-units units role)
    (define vector (list->vector units))
    (define size (vector-length vector))
    (define index 0)
    (define dummy (item (bit "" 'eof length-in #t) '()))
    (define (peek [distance 0])
      (if (< (+ index distance) size) (vector-ref vector (+ index distance)) dummy))
    (define (word? spelling [distance 0]) (equal? spelling (it-text (peek distance))))
    (define (words? spellings)
      (for/and ([spelling (in-list spellings)] [n (in-naturals)]) (word? spelling n)))
    (define (done?) (>= index size))
    (define (take!)
      (when (done?) (fail length-in "expected more source"))
      (begin0 (peek) (set! index (add1 index))))
    (define (take-word spelling)
      (unless (word? spelling) (fail (at (peek)) (format "expected ~a" spelling)))
      (take!))
    (define (group? unit [opening "["])
      (and (bracket? unit) (equal? (it-text (bracket-open unit)) opening)))
    (define (take-group mode)
      (define group (take!))
      (unless (group? group) (fail (at group) "expected ["))
      (append (raw (bracket-open group))
              (normalize-units (bracket-body group) mode)
              (raw (bracket-close group))))
    (define (wrap expr minimum)
      (if (< (expression-priority expr) minimum)
          (append (list (new "(" (peek))) (expression-bits expr) (list (new ")" (peek))))
          (expression-bits expr)))
    (define (field-start?)
      (or (word? "set") (word? "=" 1)))
    (define (parse-bracket group)
      (define members (bracket-body group))
      (define fields?
        (and (pair? members)
             (or (equal? (it-text (car members)) "set")
                 (and (pair? (cdr members)) (equal? (it-text (cadr members)) "=")))))
      (define bits
        (append (raw (bracket-open group))
                (normalize-units members (if fields? 'fields 'values))
                (raw (bracket-close group))))
      (expression bits (and (not fields?) (selection bits '())) 100))
    (define (group-selection group)
      (define body (bracket-body group))
      (and (= (length body) 1)
           (let* ([unit (car body)]
                  [spelling (it-text unit)]
                  [selected
                   (cond
                     [(group? unit "(") (group-selection unit)]
                     [(group? unit) (expression-selector (parse-bracket unit))]
                     [(and spelling (not (string-contains? spelling "."))
                           (not (regexp-match? #px"^[+:0-9-]" spelling)))
                      (selection (raw unit) '())]
                     [else #f])])
             (and selected
                  (struct-copy selection selected
                               [wrappers (cons (cons (raw (bracket-open group))
                                                     (raw (bracket-close group)))
                                               (selection-wrappers selected))])))))
    (define (atom [allow-of? #t] [rich? #t])
      (define first (take!))
      (define spelling (it-text first))
      (define base
        (cond
          [(group? first "(")
           (define contents (normalize-units (bracket-body first) 'expression))
           ;; Parentheses stay in the output, including redundant groups.
           (expression (append (raw (bracket-open first)) contents (raw (bracket-close first)))
                       (group-selection first) 100)]
          [(group? first) (parse-bracket first)]
          [(and (item? first) (equal? (bit-kind (item-token first)) 'string))
           (expression (raw first) #f 100)]
          [(member spelling '("-" "not"))
           (define priority (if (equal? spelling "-") 70 40))
           (define value (parse-expression priority))
           (expression (append (raw first) (wrap value priority)) #f priority)]
          [(equal? spelling "range")
           (define from (if (word? "from") (begin (changed!) (trivia (take!))) '()))
           (define start (parse-expression 0 '("to")))
           (define to (take-word "to"))
           (define finish (parse-expression 0 '("with" "step")))
           (define with (if (words? '("with" "step")) (begin (changed!) (trivia (take!))) '()))
           (define step (take-word "step"))
           (define increment (parse-expression))
           (expression (append (raw first) from (expression-bits start) (raw to)
                               (expression-bits finish) with (raw step) (expression-bits increment))
                       #f 100)]
          [(member spelling '("hypothesis" "assumption" "conclusion"))
           (define name (take!))
           (define object (atom))
           (expression (append (raw first) (raw name) (expression-bits object)) #f 100)]
          [(equal? spelling "is")
           (changed!)
           (define left (parse-expression 41 '("a" "in")))
           (define operator (take!))
           (cond
             [(equal? (it-text operator) "a")
              (define type (take!))
              (expression (append (trivia first) (expression-bits left)
                                  (list (new "is" first)) (trivia operator) (raw type))
                          #f 40)]
             [(equal? (it-text operator) "in")
              (define right (parse-expression 41))
              (expression (append (trivia first) (expression-bits left) (raw operator)
                                  (wrap right 41)) #f 40)]
             [else (fail (at operator) "expected a or in in a question")])]
          [else
           (define selectable?
             (and spelling (not (string-contains? spelling "."))
                  (not (string-prefix? spelling ":"))
                  (not (regexp-match? #px"^[+-]?[0-9]" spelling))
                  (not (member spelling '("true" "false" "unknown")))))
           (define pieces
             (if (and spelling (string-suffix? spelling ".") (group? (peek)))
                 (append (raw first) (expression-bits (parse-bracket (take!))))
                 (raw first)))
           (expression pieces (and selectable? (selection (raw first) '())) 100)]))
      (let postfix ([value base])
        (cond
          [(and (item? (peek)) (let ([s (it-text (peek))]) (and s (string-prefix? s "."))))
           (define suffix (take!))
           (define parts
             (if (and (string-suffix? (it-text suffix) ".") (group? (peek)))
                 (append (raw suffix) (expression-bits (parse-bracket (take!))))
                 (raw suffix)))
           (postfix (expression (append (expression-bits value) parts) #f 100))]
          [(and allow-of? (word? "of"))
           (changed!)
           (define of (take!))
           (define selector (expression-selector value))
           (unless selector (fail (at of) "of expresses one final field or bracket selection; keep the containing path dotted"))
           (define receiver (atom #f #f))
           (define selected (selection-bits selector))
           (define leading (takef selected (lambda (b) (eq? (bit-kind b) 'trivia))))
           (define significant (drop selected (length leading)))
           (define suffix
             (if (and (pair? significant) (equal? (bit-text (car significant)) "["))
                 (cons (new "." of) significant)
                 (for/list ([b (in-list significant)])
                   (if (eq? (bit-kind b) 'word)
                       (bit (string-append "." (bit-text b)) 'word (bit-offset b) #f) b))))
           (define path (append leading (expression-bits receiver) (trivia of) suffix))
           (define grouped
             (for/fold ([parts path]) ([wrapper (in-list (reverse (selection-wrappers selector)))])
               (append (car wrapper) parts (cdr wrapper))))
           (postfix (expression grouped #f 100))]
          [(and rich? (word? "with") (word? "uncertainty" 1))
           (changed!)
           (define with (take!)) (define uncertainty (take!))
           (define description (atom #f #f))
           (postfix (expression (append (expression-bits value) (replacement with "u")
                                        (trivia uncertainty) (expression-bits description)) #f 100))]
          [(and rich? (word? "with") (group? (peek 1)))
           (changed!)
           (define with (take!))
           (define fields (parse-bracket (take!)))
           (postfix (expression (append (expression-bits value) (replacement with ".")
                                        (expression-bits fields)) #f 100))]
          [(and rich? (word? "u"))
           (define u (take!)) (define description (atom #f #f))
           (postfix (expression (append (expression-bits value) (raw u)
                                        (expression-bits description)) #f 100))]
          [else value])))
    (define operator-phrases
      '((("does" "not" "equal") "!=" 40) (("is" "less" "than") "<" 40)
        (("is" "at" "most") "<=" 40) (("is" "greater" "than") ">" 40)
        (("is" "at" "least") ">=" 40) (("exclusive" "or") "xor" 20)
        (("equals") "==" 40)))
    (define (operator)
      (or
       (for/first ([entry (in-list operator-phrases)] #:when (words? (car entry))) entry)
       (let* ([word (it-text (peek))]
              [priority (cond [(member word '("*" "/")) 60]
                              [(member word '("+" "-")) 50]
                              [(member word '("==" "!=" "<" "<=" ">" ">=" "in" "is")) 40]
                              [(equal? word "and") 30] [(equal? word "xor") 20]
                              [(equal? word "or") 10] [else #f])])
         (and priority (list (list word) word priority)))))
    (define (parse-expression [minimum 0] [stops '()])
      (define first (atom))
      (let loop ([left first])
        (define op (and (not (member (it-text (peek)) stops)) (operator)))
        (if (and op (>= (caddr op) minimum))
            (let* ([phrase (car op)] [canonical (cadr op)] [priority (caddr op)]
                   [consumed (for/list ([word (in-list phrase)]) (take!))]
                   [verbal? (not (equal? phrase (list canonical)))]
                   [operator-bits
                    (if verbal?
                        (begin (changed!)
                               (append (replacement (car consumed) canonical)
                                       (append-map trivia (cdr consumed))))
                        (raw (car consumed)))])
              (define right (if (equal? canonical "is")
                                (expression (raw (take!)) #f 100)
                                (parse-expression (add1 priority) stops)))
              (loop (expression (append (wrap left priority) operator-bits
                                        (wrap right (add1 priority))) #f priority)))
            (if (< (expression-priority left) minimum)
                (expression (wrap left minimum) #f 100) left))))
    (define (parse-target) (atom #t #f))
    (define (parse-field)
      (cond
        [(word? "set")
         (changed!)
         (define set (take!)) (define target (parse-target)) (define to (take-word "to"))
         (define value (parse-expression))
         (append (trivia set) (expression-bits target) (replacement to "=") (expression-bits value))]
        [else
         (define name (take!))
         (unless (word? "=") (fail (at (peek)) "expected = after field name"))
         (define equals (take!)) (define value (parse-expression))
         (append (raw name) (raw equals) (expression-bits value))]))
    (define (condition-form opening mode)
      (define condition (parse-expression 0 '("then")))
      (define then (if (word? "then") (begin (changed!) (trivia (take!))) '()))
      (append (raw opening) (expression-bits condition) then (take-group mode)))
    (define (assignment-ahead?)
      (define saved index)
      (define answer
        (with-handlers ([exn:fail:read? (lambda (_) #f)])
          (parse-target)
          (or (member (it-text (peek)) '("=" "+=" "implement" "implements"))
              ;; A compact dotted patch is a standalone command.
              (and (> index saved) (bracket? (vector-ref vector (sub1 index)))
                   (> (- index saved) 1)))))
      (set! index saved)
      answer)
    (define (call-end?)
      (or (done?) (word? "as")
          (member (it-text (peek)) command-words)
          (words? '("start" "stage"))
          (update-ahead?)
          (assignment-ahead?)))
    (define (update-ahead?)
      (and (word? "update")
           (let ([saved index])
             (define answer
               (with-handlers ([exn:fail:read? (lambda (_) #f)])
                 (take!) (parse-target) (word? "with")))
             (set! index saved)
             answer)))
    (define (parse-call opening)
      (cond
        [(group? (peek)) (append (raw opening) (take-group 'commands))]
        [else
         (define name (take!))
         (define prefix (append (raw opening) (raw name)))
         (if (member (it-text (peek)) '("by" "with" "into"))
             (append prefix
                     (if (word? "by") (append (raw (take!)) (raw (take!))) '())
                     (if (word? "with")
                         (append (raw (take!)) (take-group 'mappings)) '())
                     (raw (take-word "into")) (expression-bits (parse-target)))
             (append prefix
                     (let loop ()
                       (if (call-end?) '()
                           (append (expression-bits (parse-expression)) (loop))))
                     (if (word? "as") (append (raw (take!)) (raw (take!))) '())))]))
    (define (parse-interface-entry)
      (cond
        [(word? "must") (append (raw (take!)) (take-group 'interface))]
        [(word? "version") (append (raw (take!)) (raw (take!)))]
        [(word? "extends") (append (raw (take!)) (raw (take!)))]
        [(word? "affects") (append (raw (take!)) (raw (take!)) (raw (take!)))]
        [(word? "affects" 1)
         (changed!)
         (define from (take!)) (define affects (take!)) (define to (take!))
         (append (raw affects) (raw from) (raw to))]
        [(word? "if") (condition-form (take!) 'interface)]
        [(word? "else")
         (define else (take!))
         (append (raw else) (if (word? "if") (condition-form (take!) 'interface)
                               (take-group 'interface)))]
        [(word? "for") (parse-for 'interface)]
        [(word? "set") (parse-field)]
        [(and (word? "is" 1) (word? "a" 2)
              (item? (peek 3)) (not (equal? (it-text (peek 3)) "")))
         (changed!)
         (define name (take!)) (define is (take!)) (define article (take!)) (define type (take!))
         (append (raw name) (raw is) (trivia article) (raw type))]
        [(word? "=" 1) (parse-field)]
        [(group? (peek 1))
         (append (raw (take!)) (take-group 'interface))]
        [else (expression-bits (parse-expression))]))
    (define (parse-for mode)
      (define for (take!)) (define each (take-word "each")) (define name (take!))
      (define in (take-word "in")) (define values (parse-expression))
      (append (raw for) (raw each) (raw name) (raw in) (expression-bits values) (take-group mode)))
    (define (parse-form)
      (cond
        [(or (words? '("set" "=")) (words? '("update" "=")) (words? '("start" "=")))
         (parse-implicit)]
        [(word? "set")
         (changed!)
         (define set (take!)) (define target (parse-target)) (define to (take-word "to"))
         (append (trivia set) (expression-bits target) (replacement to "=")
                 (expression-bits (parse-expression)))]
        [(update-ahead?)
         (changed!)
         (define update (take!)) (define target (parse-target)) (define with (take-word "with"))
         (append (trivia update) (expression-bits target) (replacement with "+=")
                 (expression-bits (parse-expression)))]
        [(words? '("start" "stage"))
         (changed!)
         (append (trivia (take!)) (parse-form))]
        [(member (it-text (peek)) '("workflow" "about" "include"))
         (append (raw (take!)) (raw (take!)))]
        [(word? "import")
         (define import (take!))
         (define verbose
           (if (words? '("library" "from"))
               (begin (changed!) (append (trivia (take!)) (trivia (take!)))) '()))
         (append (raw import) verbose (raw (take!)) (raw (take-word "at"))
                 (raw (take!)) (raw (take-word "as")) (raw (take!)))]
        [(member (it-text (peek)) '("library" "interface"))
         (define keyword (take!)) (define name (take!))
         (append (raw keyword) (raw name)
                 (take-group (if (equal? (it-text keyword) "interface") 'interface 'commands)))]
        [(word? "to")
         (define to (take!)) (define name (take!))
         (define inputs
           (let loop ()
             (if (or (done?) (group? (peek))) '() (append (raw (take!)) (loop)))))
         (append (raw to) (raw name) inputs (take-group 'commands))]
        [(member (it-text (peek)) '("performer" "resource" "hypothesis" "assumption" "conclusion"))
         (append (raw (take!)) (raw (take!)) (expression-bits (atom)))]
        [(word? "stage")
         (define stage (take!)) (define name (take!))
         (append (raw stage) (raw name)
                 (if (word? "by") (append (raw (take!)) (raw (take!))) '())
                 (if (word? "from")
                     (append (raw (take!)) (raw (take-word "state")) (expression-bits (atom))) '()))]
        [(word? "end")
         (append (raw (take!)) (raw (take-word "stage")) (raw (take-word "with"))
                 (raw (take-word "state")) (expression-bits (atom)))]
        [(word? "implements")
         ;; This older prefix form is separate from an infix mapping.
         (append (raw (take!)) (raw (take!)) (raw (take-word "as")) (raw (take!))
                 (raw (take!)))]
        [(word? "must")
         (define must (take!))
         (define extra
           (if (words? '("do" "stages" "in" "order"))
               (begin (changed!) (trivia (take!))) '()))
         (append (raw must) extra
                 (if (word? "stages")
                     (append (raw (take!)) (raw (take-word "in")) (raw (take-word "order")) (raw (take!)))
                     (append (raw (take-word "do")) (raw (take!)))))]
        [(word? "do") (parse-call (take!))]
        [(word? "if") (condition-form (take!) 'commands)]
        [(word? "else")
         (define else (take!))
         (append (raw else) (if (word? "if") (condition-form (take!) 'commands)
                               (take-group 'commands)))]
        [(word? "while")
         (define while (take!)) (define condition (parse-expression))
         (append (raw while) (expression-bits condition) (take-group 'commands))]
        [(word? "for") (parse-for 'commands)]
        [(word? "repeat")
         (define repeat (take!))
         (if (group? (peek))
             (append (raw repeat) (take-group 'commands) (raw (take-word "until"))
                     (expression-bits (parse-expression)))
             (let* ([count (parse-expression 0 '("times"))]
                    [times (if (word? "times") (begin (changed!) (trivia (take!))) '())])
               (append (raw repeat) (expression-bits count) times (take-group 'commands))))]
        [(member (it-text (peek)) '("print" "output"))
         (append (raw (take!)) (expression-bits (parse-expression)))]
        [else (parse-implicit)]))
    (define (parse-implicit)
      (define target (parse-target))
      (cond
        [(member (it-text (peek)) '("=" "+="))
         (append (expression-bits target) (raw (take!)) (expression-bits (parse-expression)))]
        [(member (it-text (peek)) '("implement" "implements"))
         (define mapping (take!))
         (define spelling
           (if (equal? (it-text mapping) "implements")
               (begin (changed!) (replacement mapping "implement")) (raw mapping)))
         (append (expression-bits target) spelling (raw (take!)))]
        [else (expression-bits target)]))
    (let loop ([backward '()])
      (if (done?) (apply append (reverse backward))
          (let ([before index]
                [parts
                 (case role
                   [(expression values) (expression-bits (parse-expression))]
                   [(fields) (parse-field)]
                   [(mappings)
                    (append (raw (take!)) (raw (take-word "at")) (expression-bits (parse-target)))]
                   [(interface) (parse-interface-entry)]
                   [else (parse-form)])])
            (when (= before index) (fail (at (peek)) "normalization made no progress"))
            (loop (cons parts backward))))))
  (define identity (normalized-source text (vector->immutable-vector originals)))
  (define pieces
    (with-handlers ([exn:fail:read? (lambda (error) (if changed? (raise error) #f))])
      (append header (normalize-units forest 'commands) (raw end-item))))
  (if (or (not pieces) (not changed?))
      identity
      (let ([out (open-output-string)] [locations '()] [last-code #f] [separated? #t])
        (define (emit-bit part)
          (define raw (bit-text part))
          (define code? (not (memq (bit-kind part) '(trivia header eof))))
          (when (and code? last-code (not separated?)
                     (not (or (string-prefix? raw ".")
                              (member (bit-text last-code) '("[" "(" "."))
                              (member raw '("]" ")" "[" "(")))))
            (display " " out)
            (set! locations (cons (vector-ref originals (bit-offset part)) locations)))
          (display raw out)
          (for ([n (in-range (string-length raw))])
            (set! locations
                  (cons (vector-ref originals
                                    (min length-in (+ (bit-offset part) (if (bit-exact? part) n 0))))
                        locations)))
          (cond
            [code? (set! last-code part) (set! separated? #f)]
            [(positive? (string-length raw)) (set! separated? #t)]))
        (for-each emit-bit pieces)
        (normalized-source (get-output-string out)
                           (vector->immutable-vector
                            (list->vector (reverse (cons (vector-ref originals length-in) locations))))))))
