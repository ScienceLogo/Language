#lang racket/base

(require racket/match
         syntax/readerr)

(provide sciencelogo-read sciencelogo-read-syntax)

(struct token (kind value line column position) #:transparent)
(struct node (kind value children at) #:transparent)

(define (read-error source at message)
  (raise-read-error message source (token-line at) (token-column at)
                    (token-position at) 1))

(define (lex in source)
  (port-count-lines! in)
  (define (at kind value)
    (define-values (line column position) (port-next-location in))
    (token kind value line column position))
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

(define (parse-program in source)
  (define tokens (list->vector (lex in source)))
  (define index 0)
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
  (define (parse-body definitions-allowed?)
    (let loop ([backward '()])
      (define found (current))
      (case (token-kind found)
        [(close) (advance!) (reverse backward)]
        [(eof) (read-error source found "expected ] before end of file")]
        [else (loop (cons (parse-form definitions-allowed?) backward))])))
  (define (parse-form definitions-allowed?)
    (define command (expect 'word "a command"))
    (match (token-value command)
      ["to"
       (unless definitions-allowed?
         (read-error source command "to definitions belong in the investigation, not a do block"))
       (define name (string->symbol (token-value (expect 'word "a procedure name"))))
       (expect 'open "[ after a procedure name")
       (node 'to name (parse-body #f) command)]
      ["do"
       (if (eq? (token-kind (current)) 'open)
           (begin
             (advance!)
             (node 'sequence #f (parse-body #f) command))
           (node 'call
                 (string->symbol (token-value (expect 'word "a procedure name")))
                 '() command))]
      ["print"
       (node 'print (token-value (expect 'string "a quoted string")) '() command)]
      [_ (read-error source command
                     (format "unsupported command ~a in the first ScienceLogo slice"
                             (token-value command)))]))
  (define start (expect-word "investigate"))
  (define question (token-value (expect 'string "a quoted investigation question")))
  (expect 'open "[ after the investigation question")
  (define forms (parse-body #t))
  (unless (eq? (token-kind (current)) 'eof)
    (read-error source (current) "expected end of file after investigation"))
  (define result (node 'investigate question forms start))
  (validate-program result source)
  (node->datum result))

(define (calls-in forms)
  (for/fold ([calls '()]) ([form (in-list forms)])
    (case (node-kind form)
      [(call) (cons form calls)]
      [(sequence) (append (calls-in (node-children form)) calls)]
      [else calls])))

(define (validate-program program source)
  (define definitions (make-hasheq))
  (for ([form (in-list (node-children program))]
        #:when (eq? (node-kind form) 'to))
    (define name (node-value form))
    (when (hash-has-key? definitions name)
      (read-error source (node-at form) (format "duplicate procedure ~a" name)))
    (hash-set! definitions name form))
  (define (check-call call)
    (unless (hash-has-key? definitions (node-value call))
      (read-error source (node-at call)
                  (format "unknown procedure ~a" (node-value call)))))
  (for ([call (in-list (calls-in (node-children program)))]) (check-call call))
  (for ([definition (in-hash-values definitions)])
    (for ([call (in-list (calls-in (node-children definition)))])
      (check-call call)))
  (define visited (make-hasheq))
  (define active (make-hasheq))
  (define (visit name)
    (hash-set! active name #t)
    (for ([call (in-list (calls-in (node-children (hash-ref definitions name))))])
      (define target (node-value call))
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
    [(investigate) (list 'investigate (node-value form)
                         (map node->datum (node-children form)))]
    [(to) (list 'to (node-value form) (map node->datum (node-children form)))]
    [(call) (list 'call (node-value form))]
    [(sequence) (list 'sequence (map node->datum (node-children form)))]
    [(print) (list 'print (node-value form))]))

(define (sciencelogo-read in)
  (list (list 'run-program (list 'quote (parse-program in (object-name in))))))

(define (sciencelogo-read-syntax source in)
  (list (datum->syntax #f
                       (list 'run-program (list 'quote (parse-program in source)))
                       (list source #f #f #f #f))))
