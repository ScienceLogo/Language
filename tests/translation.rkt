#lang racket/base

(require rackunit racket/file racket/list racket/path racket/port racket/runtime-path
         racket/string racket/system "../normalize.rkt" "../private/reader.rkt")

(define (convert text target)
  (normalized-source-text (translate-source text #:to target)))
(define (tokens text)
  (regexp-match* #px"\"(?:[^\"\\\\]|\\\\.)*\"|[^\\s\\[\\]().]+|[\\[\\]().]" text))
(define-runtime-path examples "../examples")

(module+ test
  ;; Exact spellings are tested independently of reader/runtime equivalence.
  ;; Both target choices accept every input spelling, without an input flag.
  (for ([pair (in-list
               '(("period = 2" "set period to 2")
                 ("trial.period = 3" "set period of trial to 3")
                 ("x = experiment.trial.period" "set x to period of experiment.trial")
                 ("x = trials.[1 3]" "set x to [1 3] of trials")
                 ("x = trial.[period unit]" "set x to [period unit] of trial")
                 ("x = grid.[1].[2]" "set x to [2] of grid.[1]")
                 ("x = values.count" "set x to count of values")
                 ("x = period.u" "set x to u of period")
                 ("trial = [duration = 20 unit = \"s\"]"
                  "set trial to [set duration to 20 set unit to \"s\"]")
                 ("trial = [clock = [time = 1]]" "set trial to [set clock to [set time to 1]]")
                 ("trial.period += 2" "update period of trial with 2")
                 ("values += [3 4]" "update values with [3 4]")
                 ("values.[2] = 3" "set [2] of values to 3")
                 ("x = Timing.[duration = 20]" "set x to Timing with [set duration to 20]")
                 ("x = tools.Timing.[]" "set x to tools.Timing with []")
                 ("x = trial.[period = 3]" "set x to trial with [set period to 3]")
                 ("x = values.[2 = 3]" "set x to values with [set 2 to 3]")
                 ("x = 2 u [declared = [timing = [estimate = 0.1]]]"
                  "set x to 2 with uncertainty [set declared to [set timing to [set estimate to 0.1]]]")
                 ("if x == 2 [print x]" "if x equals 2 then [print x]")
                 ("if x != 2 []" "if x does not equal 2 then []")
                 ("if x < 2 []" "if x is less than 2 then []")
                 ("if x <= 2 []" "if x is at most 2 then []")
                 ("if x > 2 []" "if x is greater than 2 then []")
                 ("if x >= 2 []" "if x is at least 2 then []")
                 ("if a xor b []" "if a exclusive or b then []")
                 ("if ready and not excluded or false []" "if ready and not excluded or false then []")
                 ("if x in values []" "if is x in values then []")
                 ("if notes in trial []" "if is notes in trial then []")
                 ("if period is number []" "if is period a number then []")
                 ("if trial is tools.Timing []" "if is trial a tools.Timing then []")
                 ("x = range 0.25 to 1 step 0.25" "set x to range from 0.25 to 1 with step 0.25")
                 ("repeat 3 [print 2]" "repeat 3 times [print 2]")
                 ("if true [] else if false [] else []" "if true then [] else if false then [] else []")
                 ("while x < 2 [x += 1]" "while x is less than 2 [update x with 1]")
                 ("repeat [x += 1] until x >= 2" "repeat [update x with 1] until x is at least 2")
                 ("for each x in values [print x]" "for each x in values [print x]")
                 ("stage measure" "start stage measure")
                 ("stage measure by observer from state [information = [period = unknown]]"
                  "start stage measure by observer from state [set information to [set period to unknown]]")
                 ("end stage with state [information = [period = unknown]]"
                  "end stage with state [set information to [set period to unknown]]")
                 ("do tools.estimate with [duration at information.elapsed] into information.period"
                  "do tools.estimate with [duration at elapsed of information] into period of information")
                 ("to echo :trial [output :trial.period]" "to echo :trial [output period of :trial]")
                 ("do tools.estimate trial.duration trial.swings as period"
                  "do tools.estimate duration of trial swings of trial as period")
                 ("interface Timing [must [duration is number unit = \"s\"] notes is text]"
                  "interface Timing [must [duration is a number set unit to \"s\"] notes is a text]")
                 ("interface Timing [must [period = unknown number timing = unknown tools.Timing]]"
                  "interface Timing [must [set period to unknown number set timing to unknown tools.Timing]]")
                 ("interface P [must [measurement analysis] affects measurement analysis]"
                  "interface P [must [measurement analysis] measurement affects analysis]")
                 ("interface P [must [trials] for each trial in trials [must [trial.period > 0]]]"
                  "interface P [must [trials] for each trial in trials [must [period of trial is greater than 0]]]")
                 ("measure implement tools.Protocol.measurement" "measure implements tools.Protocol.measurement")
                 ("tools.measure implement tools.Protocol" "tools.measure implements tools.Protocol")
                 ("must stages in order [prepare measure]" "must do stages in order [prepare measure]")
                 ("must do estimate" "must do estimate")
                 ("import \"file:///tmp/lib\" at \"v1\" as lib"
                  "import library from \"file:///tmp/lib\" at \"v1\" as lib")
                 ("library hello-world [to greeting [output \"Hello, world!\"]]"
                  "library hello-world [to greeting [output \"Hello, world!\"]]")
                 ("performer observer [kind = \"human\"]" "performer observer [set kind to \"human\"]")
                 ("resource timings [path = \"timings.csv\"]" "resource timings [set path to \"timings.csv\"]")
                 ("elapsed = timings.elapsed" "set elapsed to elapsed of timings")
                 ("timings.period = elapsed" "set period of timings to elapsed")
                 ("hypothesis shorter-swing [text = \"A smaller swing has a shorter period\"]"
                  "hypothesis shorter-swing [set text to \"A smaller swing has a shorter period\"]")
                 ("hypotheses.shorter-swing += conclusion answer [text = \"Not supported\"]"
                  "update shorter-swing of hypotheses with conclusion answer [set text to \"Not supported\"]")
                 ("implements \"protocol.rkt\" as p [provide measurement by \"Manual timing\"]"
                  "implements \"protocol.rkt\" as p [provide measurement by \"Manual timing\"]")))])
    (define compact (car pair))
    (define verbose (cadr pair))
    (for ([input (in-list (list compact verbose))])
      (check-equal? (tokens (convert input 'verbose)) (tokens verbose) input)
      (check-equal? (tokens (convert input 'compact)) (tokens compact) input)
      (for ([target '(compact verbose)])
        (define once (convert input target))
        (check-equal? (convert once target) once (format "stable ~a: ~a" target input))))
    (check-equal? (tokens (convert (convert compact 'verbose) 'compact)) (tokens compact) compact)
    (check-equal? (tokens (convert (convert verbose 'compact) 'verbose)) (tokens verbose) verbose))

  (define mixed
    (string-append
     "#lang sciencelogo\nworkflow \"Mixed spellings\"\n"
     "about \"Keep set x to 2 and trial.period as Markdown text.\"\n"
     "trial = [duration = 20 set swings to 10]\n"
     "set period to trial.duration / swings of trial\n"
     "if period >= 2 and not (is notes in trial) then [print period]\n"))
  (define compact-mixed (convert mixed 'compact))
  (define verbose-mixed (convert mixed 'verbose))
  (check-true (string-contains? verbose-mixed "set trial to"))
  (check-true (string-contains? verbose-mixed "duration of trial"))
  (check-true (string-contains? verbose-mixed "is at least"))
  (check-equal? (tokens (convert verbose-mixed 'compact)) (tokens compact-mixed))
  (check-equal? (tokens (convert compact-mixed 'verbose)) (tokens verbose-mixed))

  (define indented-compact
    (string-append
     "#lang sciencelogo\ntrial = [\n  duration = 20\n  swings = 10\n]\n"
     "if trial.duration >= 20 [\n  print ((trial.duration / trial.swings))\n]\n"))
  (define indented-verbose
    (string-append
     "#lang sciencelogo\nset trial to [\n  set duration to 20\n  set swings to 10\n]\n"
     "if duration of trial is at least 20 then [\n  print ((duration of trial / swings of trial))\n]\n"))
  (for ([input (list indented-compact indented-verbose
                     (string-replace indented-compact "duration = 20" "set duration to 20"))])
    (for ([target '(compact verbose)]
          [expected (list indented-compact indented-verbose)])
      (check-equal? (convert input target) expected)
      (check-equal? (for/fold ([text input]) ([_ (in-range 4)]) (convert text target)) expected)))

  (define laid-out
    (string-append
     "#lang sciencelogo\nabout \"A description\n  with indented Markdown.\"\n"
     "#| Keep this comment\n   #| and this nesting |#\n|#\n"
     "to echo :input [\n\t; Keep this comment too.\n\toutput (((:input)))\n]\n"
     "\nset result to 2\nprint result\n"))
  (check-equal? (convert laid-out 'verbose) laid-out)
  (check-equal? (convert (convert laid-out 'compact) 'verbose) laid-out)
  (check-equal? (convert "set x to 2" 'verbose) "set x to 2")
  (check-equal? (convert "\tset x to 2\n" 'verbose) "\tset x to 2\n")
  (check-equal? (normalized-source-text
                 (translate-source "  set x to 2" #:to 'verbose #:column 5 #:position 20))
                "  set x to 2")
  (define line-endings "#lang sciencelogo\r\ntrial = [\r\n  period = 2\r\n]\r\n")
  (define line-endings-output (convert line-endings 'verbose))
  (check-equal? line-endings-output
                "#lang sciencelogo\r\nset trial to [\r\n  set period to 2\r\n]\r\n")
  (check-equal? (convert line-endings-output 'verbose) line-endings-output)

  ;; Reuse every distributed source example, including relative interface
  ;; references, rather than reducing translation tests to spelling checks.
  (define directory (make-temporary-file "sciencelogo-translation~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define corpus (build-path directory "examples"))
      (copy-directory/files examples corpus)
      (define files (find-files (lambda (p) (and (file-exists? p) (regexp-match? #rx"[.]rkt$" (path->string p)))) corpus))
      (for ([path (in-list files)])
        (define original (file->string path))
        (define expected (parse-sciencelogo-file path))
        (for ([target '(verbose compact)])
          (define converted (convert original target))
          (define output (build-path (path-only path) "translated.rkt"))
          (display-to-file converted output #:exists 'truncate)
          (check-equal? (parse-sciencelogo-file output) expected (format "~a: ~a" path target))
          (check-equal? (convert converted target) converted (format "stable ~a: ~a" path target))))

      (define (run text)
        (define file (make-temporary-file "method~a.rkt" #f directory))
        (display-to-file (string-append "#lang sciencelogo\n" text) file #:exists 'truncate)
        (with-output-to-string (lambda () (dynamic-require file #f))))
      (define method
        (string-append
         "interface Timing [must [duration unit = \"seconds\"]]\n"
         "to estimate :duration :swings [output :duration / :swings]\n"
         "trial = Timing.[duration = 20]\ntrial += [swings = 10]\n"
         "do estimate trial.duration trial.swings as period\nprint period\n"
         "values = [1 2]\nvalues.[2] = 3\nvalues += [4 5]\nprint values.[3].[2]\n"
         "values.[1 = 9]\nprint values\n"
         "trial.[duration = 40]\nprint trial.duration\n"
         "hypothesis shorter-swing [text = \"A smaller swing has a shorter period\"]\n"
         "hypotheses.shorter-swing += conclusion answer [text = \"Not supported\"]\n"
         "print hypotheses.shorter-swing.conclusions.answer.text\n"
         "counter = 0\nwhile counter < 2 [counter += 1]\nrepeat 2 [print counter]\n"
         "repeat [counter += 1] until counter >= 4\n"
         "if counter == 4 [print \"four\"] else if counter != 4 [] else []\n"))
      (check-equal? (run (convert method 'verbose)) (run method))
      (check-equal? (run (convert (convert method 'verbose) 'compact)) (run method))
      (check-equal? (run (convert "times = 2\nthen = true\nupdate = 3\nrepeat times [if then [print update]]\n" 'verbose))
                    "3\n3\n")
      (define grouped "trial = [period = 2]\nprint (((trial.period)))\nprint ((trial)).period\n")
      (check-equal? (run (convert grouped 'verbose)) (run grouped))
      (check-equal? (length (regexp-match* #rx"[(]" (convert grouped 'verbose))) 5)
      (check-equal? (length (regexp-match* #rx"[)]" (convert grouped 'verbose))) 5)
      (define crlf-program
        "; α\r\ntrial = [\r\n  period = 2\r\n]\r\nprint ((trial.period))\r\n")
      (check-equal? (run crlf-program) "2\n")
      (check-equal? (run (convert crlf-program 'verbose)) "2\n")
      (check-equal? (run (convert (convert crlf-program 'verbose) 'compact)) "2\n")
      (define crlf-error (build-path directory "crlf-error.rkt"))
      (display-to-file "#lang sciencelogo\r\n; α\r\nset result to missing\r\n" crlf-error)
      (check-exn
       (lambda (error)
         (and (exn:fail:read? error)
              (let ([where (car (exn:fail:read-srclocs error))])
                (and (= (srcloc-line where) 3) (= (srcloc-column where) 14)))))
       (lambda () (parse-sciencelogo-file crlf-error)))
      (define expressions
        (string-append
         "trial = [period = 2.01 unit = \"s\"]\nvalues = [1 2 3]\n"
         "print (trial.[period = 3]).period\n"
         "print trial.[period = 4].period\n"
         "print ((trial).period)\n"
         "print values.[(1 + 1)]\n"
         "print (trial.period u [declared = []]).u\n"
         "print trial.period * 2 + - trial.period\n"
         "print (trial.period < 3 and not (trial.period == unknown)) xor false\n"
         "print (1 + 2) in values\n"))
      (check-equal? (run (convert expressions 'verbose)) (run expressions))
      (define command-input (build-path directory "mixed.rkt"))
      (display-to-file mixed command-input)
      (for ([target '(compact verbose)])
        (define out (open-output-string))
        (define err (open-output-string))
        (define success?
          (parameterize ([current-output-port out] [current-error-port err])
            (system* (find-executable-path (find-system-path 'exec-file))
                     "-l" "sciencelogo/translate" "--" "--to" (symbol->string target)
                     (path->string command-input))))
        (check-true success? (get-output-string err))
        (check-equal? (tokens (get-output-string out)) (tokens (convert mixed target)))))
    (lambda () (delete-directory/files directory)))

  (define annotated
    (string-append
     "#lang sciencelogo\n; α keep set and of\n"
     "about \"set x to 2; #| not a comment |#\"\n"
     "trial #| target |# = [period = 2]\n"
     "print trial #| access #| nested |# text |# .period ; after\n"))
  (define result (translate-source annotated #:to 'verbose #:source 'original
                                   #:line 7 #:column 0 #:position 20))
  (define translated (normalized-source-text result))
  (for ([text '("; α keep set and of\n" "\"set x to 2; #| not a comment |#\""
                "#| target |#" "#| access #| nested |# text |#" "; after\n")])
    (check-equal? (length (regexp-match* (regexp (regexp-quote text)) translated)) 1))
  (define selected (add1 (caar (regexp-match-positions #rx"print period" translated))))
  (define period-origin (normalized-source-origin result (+ selected 6)))
  (check-equal? (source-origin-source period-origin) 'original)
  (check-equal? (source-origin-line period-origin) 11)
  (check-equal? (source-origin-position period-origin)
                (+ 20 (caar (regexp-match-positions #rx"period ; after" annotated))))
  (check-equal? (source-origin-span
                (normalized-source-origin result (add1 (string-length translated)))) 0)
  (check-equal? (vector-length (normalized-source-origins result)) (add1 (string-length translated)))
  ;; Comments on a receiver duplicated by assignment-back occur only once.
  (define patched (convert "; before\ntrial #| receiver |# .[period = 3] ; after\n" 'verbose))
  (for ([comment '("; before\n" "#| receiver |#" "; after\n")])
    (check-equal? (length (regexp-match* (regexp (regexp-quote comment)) patched)) 1))
  (define crlf "#lang sciencelogo\r\n; keep\r\nset period to 2\r\n")
  (check-true (string-contains? (convert crlf 'verbose) "; keep\r\n"))
  (check-exn exn:fail:contract? (lambda () (translate-source "x = 2" #:to 'mixed)))
  (check-exn exn:fail:read? (lambda () (translate-source "x = [1" #:to 'verbose)))
  (check-exn
   (lambda (error)
     (and (exn:fail:read? error)
          (let ([where (car (exn:fail:read-srclocs error))])
            (and (eq? (srcloc-source where) 'original) (= (srcloc-line where) 8)))))
   (lambda () (translate-source "; prefix\nx =" #:to 'verbose #:source 'original
                               #:line 7 #:position 20))))
