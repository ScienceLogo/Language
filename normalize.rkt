#lang racket/base

(require racket/list racket/match racket/port racket/string syntax/readerr
         "private/source-offsets.rkt")

(provide normalize-source translate-source normalized-source-origin
         (struct-out normalized-source) (struct-out source-origin))

;; Origins are indexed by output character, with one final entry for EOF.
(struct source-origin (source line column position span) #:transparent)
(struct normalized-source (text origins) #:transparent)
(struct bit (text kind offset exact?) #:transparent)
(struct item (token leading) #:transparent)
(struct bracket (open body close) #:transparent)
(struct expression (bits selector priority) #:transparent)
(struct selection (bits wrappers) #:transparent)
(struct access (receiver selector anchor fields?) #:transparent)

(define verbose-operators
  (hash "==" "equals" "!=" "does not equal" "<" "is less than" "<=" "is at most"
        ">" "is greater than" ">=" "is at least" "xor" "exclusive or"))

(define (normalized-source-origin result position)
  (unless (and (exact-positive-integer? position)
               (<= position (vector-length (normalized-source-origins result))))
    (raise-argument-error 'normalized-source-origin
                          "a one-based position in the normalized source, including EOF" position))
  (vector-ref (normalized-source-origins result) (sub1 position)))

(define (normalize-source text #:source [source #f]
                          #:line [first-line 1] #:column [first-column 0]
                          #:position [first-position 1])
  (rewrite-source text #f #:source source #:line first-line
                  #:column first-column #:position first-position))

;; No input dialect flag: all source goes through compact normalization.
;; The second pass uses the first pass's origins directly, including errors.
(define (translate-source text #:to target #:source [source #f]
                          #:line [first-line 1] #:column [first-column 0]
                          #:position [first-position 1])
  (unless (memq target '(compact verbose))
    (raise-argument-error 'translate-source "(or/c 'compact 'verbose)" target))
  (define compact
    (rewrite-source text #f #:source source #:line first-line
                    #:column first-column #:position first-position
                    #:format? (eq? target 'compact)))
  (if (eq? target 'compact) compact
      (rewrite-source (normalized-source-text compact) #t #:source source
                      #:origins (normalized-source-origins compact)
                      #:format? #t #:layout-column first-column)))

(define (rewrite-source text verbose? #:source [source #f]
                        #:line [first-line 1] #:column [first-column 0]
                        #:position [first-position 1] #:origins [input-origins #f]
                        #:format? [format? #f] #:layout-column [layout-column first-column])
  (unless (string? text) (raise-argument-error 'normalize-source "string?" text))
  (define length-in (string-length text))
  (define input (open-input-string text source))
  (port-count-lines! input)
  (set-port-next-location! input first-line first-column first-position)
  (define originals
    (or input-origins
        (let ([port (open-input-string text source)])
          (port-count-lines! port)
          (set-port-next-location! port first-line first-column first-position)
          (list->vector
           (let loop ([backward '()])
             (define-values (line column position) (port-next-location port))
             (define next (read-char port))
             (define at (source-origin source line column position (if (eof-object? next) 0 1)))
             (if (eof-object? next) (reverse (cons at backward))
                 (loop (cons at backward))))))))
  (define offset (make-character-offset text input))
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
  (define (prepend spelling bits anchor)
    (define leading (takef bits (lambda (b) (eq? (bit-kind b) 'trivia))))
    (append leading (list (new spelling anchor)) (drop bits (length leading))))
  (define (slice part begin end)
    (bit (substring (bit-text part) begin end) (bit-kind part)
         (+ (bit-offset part) (if (bit-exact? part) begin 0)) (bit-exact? part)))
  ;; Split only the final access outside explicit brackets and groups. A
  ;; containing path stays dotted, including imported interface constructors.
  (define (split-access bits)
    (define cut #f)
    (define depth 0)
    (for ([part (in-list bits)] [index (in-naturals)])
      (define spelling (bit-text part))
      (when (and (zero? depth) (eq? (bit-kind part) 'word)
                 (not (string->number spelling)))
        (for ([c (in-string spelling)] [offset (in-naturals)] #:when (char=? c #\.))
          (set! cut (list index offset))))
      (when (memq (bit-kind part) '(delimiter word))
        (cond [(member spelling '("[" "(")) (set! depth (add1 depth))]
              [(member spelling '("]" ")")) (set! depth (sub1 depth))])))
    (and cut
         (let* ([index (car cut)] [offset (cadr cut)] [part (list-ref bits index)]
                [size (string-length (bit-text part))]
                [receiver (append (take bits index)
                                  (if (zero? offset) '() (list (slice part 0 offset))))]
                [selector (append (if (= (add1 offset) size) '()
                                      (list (slice part (add1 offset) size)))
                                  (drop bits (add1 index)))]
                [code (filter (lambda (b) (not (eq? (bit-kind b) 'trivia))) selector)]
                [fields? (and (pair? code) (equal? (bit-text (car code)) "[")
                              (pair? (cdr code))
                              (or (member (bit-text (cadr code)) '("]" "set"))
                                  (and (pair? (cddr code))
                                       (equal? (bit-text (caddr code)) "="))))])
           (and (pair? receiver) (pair? selector)
                (access receiver selector (slice part offset (add1 offset)) fields?)))))
  (define (verbose-access bits)
    (define path (and verbose? (split-access bits)))
    (cond
      [(not path) bits]
      [else
       (changed!)
       (define receiver (access-receiver path))
       (define leading (takef receiver (lambda (b) (eq? (bit-kind b) 'trivia))))
       (define anchor (access-anchor path))
       (if (access-fields? path)
           (append receiver (list (bit "with" 'word (bit-offset anchor) #f))
                   (access-selector path))
           (append leading (access-selector path)
                   (list (bit "of" 'word (bit-offset anchor) #f))
                   (drop receiver (length leading))))]))
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
    (define (atom [allow-of? #t] [rich? #t] [verbal-path? #t])
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
           (when verbose? (changed!))
           (expression (append (if verbose? (replacement first "range from") (raw first))
                               from (expression-bits start) (raw to)
                               (expression-bits finish) with
                               (if verbose? (replacement step "with step") (raw step))
                               (expression-bits increment))
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
      (let postfix ([value base]
                    [needs-access? (not (member spelling '("range" "-" "not" "is"
                                                           "hypothesis" "assumption" "conclusion")))])
        (cond
          [(and (item? (peek)) (let ([s (it-text (peek))]) (and s (string-prefix? s "."))))
           (define suffix (take!))
           (define parts
             (if (and (string-suffix? (it-text suffix) ".") (group? (peek)))
                 (append (raw suffix) (expression-bits (parse-bracket (take!))))
                 (raw suffix)))
           (define receiver
             (if (and verbose? (not needs-access?))
                 (append (list (new "(" suffix)) (expression-bits value) (list (new ")" suffix)))
                 (expression-bits value)))
           (postfix (expression (append receiver parts) #f 100) #t)]
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
           (postfix (expression grouped #f 100) needs-access?)]
          [(and rich? (word? "with") (word? "uncertainty" 1))
           (changed!)
           (define with (take!)) (define uncertainty (take!))
           (define description (atom #f #f))
           (postfix (expression (append (expression-bits value) (replacement with "u")
                                        (trivia uncertainty) (expression-bits description)) #f 100) #f)]
          [(and rich? (word? "with") (group? (peek 1)))
           (changed!)
           (define with (take!))
           (define fields (parse-bracket (take!)))
           (postfix (expression (append (expression-bits value) (replacement with ".")
                                        (expression-bits fields)) #f 100) needs-access?)]
          [(and rich? (word? "u"))
           (define u (take!)) (define description (atom #f #f))
           (when verbose? (changed!))
           (postfix (expression (append (if needs-access? (verbose-access (expression-bits value))
                                           (expression-bits value))
                                        (if verbose? (replacement u "with uncertainty") (raw u))
                                        (expression-bits description)) #f 100) #f)]
          [else (if (and verbose? verbal-path? needs-access?)
                    (struct-copy expression value [bits (verbose-access (expression-bits value))])
                    value)])))
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
                    (cond
                      [(and verbose? (member canonical '("==" "!=" "<" "<=" ">" ">=" "xor")))
                       (changed!)
                       (replacement (car consumed)
                                    (hash-ref verbose-operators canonical))]
                      [verbal?
                        (begin (changed!)
                               (append (replacement (car consumed) canonical)
                                       (append-map trivia (cdr consumed))))]
                      [else (raw (car consumed))])])
              (define right (if (equal? canonical "is")
                                (expression (raw (take!)) #f 100)
                                (parse-expression (add1 priority) stops)))
              (define parts
                (if (and verbose? (member canonical '("in" "is")))
                    (begin
                      (changed!)
                      (prepend "is"
                               (append (wrap left (add1 priority))
                                       (if (equal? canonical "is")
                                           (replacement (car consumed) "a") operator-bits)
                                       (wrap right (add1 priority)))
                               (car consumed)))
                    (append (wrap left priority) operator-bits (wrap right (add1 priority)))))
              (loop (expression parts #f priority)))
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
         (if verbose?
             (begin (changed!)
                    (append (prepend "set" (raw name) name) (replacement equals "to")
                            (expression-bits value)))
             (append (raw name) (raw equals) (expression-bits value)))]))
    (define (condition-form opening mode)
      (define condition (parse-expression 0 '("then")))
      (define then (if (word? "then") (begin (changed!) (trivia (take!))) '()))
      (when verbose? (changed!))
      (append (raw opening) (expression-bits condition) then
              (if verbose? (list (new "then" (peek))) '()) (take-group mode)))
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
        [(word? "affects")
         (define affects (take!)) (define from (take!)) (define to (take!))
         (if verbose?
             (begin (changed!)
                    (append (trivia affects) (raw from) (list (new "affects" affects)) (raw to)))
             (append (raw affects) (raw from) (raw to)))]
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
        [(and (word? "is" 1) (not (member (it-text (peek 2)) '("less" "at" "greater"))))
         (define name (take!)) (define is (take!)) (define type (take!))
         (when verbose? (changed!))
         (append (raw name) (raw is) (if verbose? (list (new "a" is)) '()) (raw type))]
        [(group? (peek 1))
         (append (raw (take!)) (take-group 'interface))]
        [else
         ;; Bare entry/type names are references, not field reads. In
         ;; particular, an imported typed-unknown suffix stays qualified.
         (define saved index)
         (define simple? (and (item? (peek)) (eq? (bit-kind (item-token (peek))) 'word)
                              (not (member (it-text (peek)) '("not" "-" "is")))))
         (define following-operator?
           (and simple? (begin (set! index (add1 index)) (begin0 (operator) (set! index saved)))))
         (define path-ahead?
           (or (and (it-text (peek 1)) (string-prefix? (it-text (peek 1)) "."))
               (and (it-text (peek)) (string-suffix? (it-text (peek)) "."))))
         (if (and verbose? simple? (not following-operator?) (not path-ahead?))
             (raw (take!)) (expression-bits (parse-expression)))]))
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
         (when verbose? (changed!))
         (append (if verbose? (replacement import "import library from") (raw import))
                 verbose (raw (take!)) (raw (take-word "at"))
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
         (when verbose? (changed!))
         (append (if verbose? (replacement stage "start stage") (raw stage)) (raw name)
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
                     (begin
                       (when verbose? (changed!))
                       (append (if verbose? (list (new "do" (peek))) '())
                               (raw (take!)) (raw (take-word "in")) (raw (take-word "order")) (raw (take!))))
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
               (when verbose? (changed!))
               (append (raw repeat) (expression-bits count) times
                       (if verbose? (list (new "times" (peek))) '()) (take-group 'commands))))]
        [(member (it-text (peek)) '("print" "output"))
         (append (raw (take!)) (expression-bits (parse-expression)))]
        [else (parse-implicit)]))
    (define (parse-implicit)
      (define target (atom #t #f #f))
      (cond
        [(member (it-text (peek)) '("=" "+="))
         (define operator (take!))
         (define value (parse-expression))
         (if verbose?
             (let ([addition? (equal? (it-text operator) "+=")])
               (changed!)
               (append (prepend (if addition? "update" "set")
                                (verbose-access (expression-bits target)) operator)
                       (replacement operator (if addition? "with" "to"))
                       (expression-bits value)))
             (append (expression-bits target) (raw operator) (expression-bits value)))]
        [(member (it-text (peek)) '("implement" "implements"))
         (define mapping (take!))
         (define spelling
           (if verbose?
               (begin (changed!) (replacement mapping "implements"))
               (if (equal? (it-text mapping) "implements")
                   (begin (changed!) (replacement mapping "implement")) (raw mapping))))
         (append (expression-bits target) spelling (raw (take!)))]
        [else
         (define bits (expression-bits target))
         (define path (and verbose? (split-access bits)))
         (if (and path (access-fields? path))
             (let* ([leading (takef bits (lambda (b) (eq? (bit-kind b) 'trivia)))]
                    [name (filter (lambda (b) (not (eq? (bit-kind b) 'trivia))) (access-receiver path))]
                    [anchor (bit-offset (access-anchor path))])
               (changed!)
               (append leading (list (bit "set" 'word anchor #f)) (verbose-access name)
                       (list (bit "to" 'word anchor #f))
                       (verbose-access (drop bits (length leading)))))
             bits)]))
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
    (with-handlers ([exn:fail:read? (lambda (error) (if (or verbose? changed?) (raise error) #f))])
      (append header (normalize-units forest 'commands) (raw end-item))))
  (if (or (not pieces) (and (not changed?) (not format?)))
      identity
      (let ([out (open-output-string)] [locations '()] [last-code #f] [separated? #t])
        (define pending '())
        (define line-start? #t)
        (define last-character #f)
        (define indent-column layout-column)
        (define (origin part n)
          (vector-ref originals
                      (min length-in (+ (bit-offset part) (if (bit-exact? part) n 0)))))
        (define (put! c where)
          (write-char c out)
          (set! locations (cons where locations))
          (set! last-character c)
          (cond
            [(memv c '(#\return #\newline))
             (set! line-start? #t) (set! indent-column 0)]
            [(not (char-whitespace? c)) (set! line-start? #f)]))
        (define (horizontal? entry)
          (not (memv (car entry) '(#\return #\newline))))
        ;; Removing alias words can bring several former separators together.
        ;; Keep line endings and authentic indentation, using the original
        ;; character positions to distinguish indentation from those gaps.
        ;; Comments and strings never enter this whitespace buffer.
        (define (flush-whitespace! eof? next-text)
          (define entries (reverse pending))
          (set! pending '())
          (let loop ([remaining entries])
            (unless (null? remaining)
              (define horizontal (takef remaining horizontal?))
              (define rest (drop remaining (length horizontal)))
              (cond
                [(pair? rest)
                 ;; Horizontal whitespace before a line ending is trailing.
                 (put! (caar rest) (cdar rest))
                 (loop (cdr rest))]
                [(and (pair? horizontal) (not eof?))
                 (cond
                   [line-start?
                    (let indent ([spaces horizontal] [next-position #f])
                      (unless (null? spaces)
                        (define where (cdar spaces))
                        (when (if next-position
                                  (= (source-origin-position where) next-position)
                                  (= (source-origin-column where) indent-column))
                          (put! (caar spaces) where)
                          (indent (cdr spaces) (add1 (source-origin-position where))))))]
                   [(or (memv last-character '(#\[ #\( #\.))
                        (member next-text '("]" ")"))
                        (string-prefix? next-text "."))
                    (void)]
                   [else (put! #\space (cdar horizontal))])]))))
        (define (emit-bit part)
          (define raw (bit-text part))
          (define code? (not (memq (bit-kind part) '(trivia header eof))))
          (cond
            [(and format? (eq? (bit-kind part) 'trivia)
                  (for/and ([c (in-string raw)]) (char-whitespace? c)))
             (for ([c (in-string raw)] [n (in-naturals)])
               (set! pending (cons (cons c (origin part n)) pending)))]
            [else
             (when format? (flush-whitespace! (eq? (bit-kind part) 'eof) raw))
             (when (and code? last-code (not separated?)
                        (not (or (string-prefix? raw ".")
                                 (member (bit-text last-code) '("[" "(" "."))
                                 (and verbose? (string-suffix? (bit-text last-code) "."))
                                 (member raw (if verbose? '("]" ")") '("]" ")" "[" "("))))))
               (put! #\space (origin part 0)))
             (for ([c (in-string raw)] [n (in-naturals)]) (put! c (origin part n)))])
          (cond
            [code? (set! last-code part) (set! separated? #f)]
            [(positive? (string-length raw)) (set! separated? #t)]))
        (for-each emit-bit pieces)
        (normalized-source (get-output-string out)
                           (vector->immutable-vector
                            (list->vector (reverse (cons (vector-ref originals length-in) locations))))))))
