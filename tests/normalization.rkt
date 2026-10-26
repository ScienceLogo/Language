#lang racket/base
(require "git-fixture.rkt"
         rackunit racket/file racket/list racket/path racket/port racket/string racket/system
         "../normalize.rkt" "../private/reader.rkt")
(define (compact text) (normalized-source-text (normalize-source text)))
(define (with-source text use)
  (define path (make-temporary-file "sciencelogo-normalization~a.rkt"))
  (dynamic-wind
    (lambda () (display-to-file (string-append "#lang sciencelogo\n" text) path #:exists 'truncate))
    (lambda () (use path))
    (lambda () (delete-file path))))
(define (datum text) (with-source text parse-sciencelogo-file))
(define (run text)
  (with-source text (lambda (path) (with-output-to-string (lambda () (dynamic-require path #f))))))
(module+ test
  (for ([pair (in-list
               '(("set x to 2" "x = 2")
                 ("set trial to [set period to 2]" "trial = [period = 2]")
                 ("set period of trial to 3" "trial.period = 3")
                 ("set x to period of experiment.trial" "x = experiment.trial.period")
                 ("set x to [1 3] of trials" "x = trials.[1 3]")
                 ("update values with [3 4]" "values += [3 4]")
                 ("set x to trial with [set period to 3]" "x = trial.[period = 3]")
                 ("set x to 2 with uncertainty [set declared to []]" "x = 2 u [declared = []]")
                 ("if x equals 2 then [print x]" "if x == 2 [print x]")
                 ("if x does not equal 2 then [print x]" "if x != 2 [print x]")
                 ("if x is less than 2 then [print x]" "if x < 2 [print x]")
                 ("if x is at most 2 then [print x]" "if x <= 2 [print x]")
                 ("if x is greater than 2 then [print x]" "if x > 2 [print x]")
                 ("if x is at least 2 then [print x]" "if x >= 2 [print x]")
                 ("if a exclusive or b then [print a]" "if a xor b [print a]")
                 ("if is x in values then [print x]" "if x in values [print x]")
                 ("if is x a number then [print x]" "if x is number [print x]")
                 ("set xs to range from 0 to 2 with step 1" "xs = range 0 to 2 step 1")
                 ("repeat 3 times [print 2]" "repeat 3 [print 2]")
                 ("start stage measure" "stage measure")
                 ("measure implements Protocol.measurement" "measure implement Protocol.measurement")
                 ("must do stages in order [prepare measure]" "must stages in order [prepare measure]")
                 ("interface Timing [must [duration is a number set unit to \"s\"]]"
                  "interface Timing [must [duration is number unit = \"s\"]]")
                 ("interface Protocol [must [measurement analysis] measurement affects analysis]"
                  "interface Protocol [must [measurement analysis] affects measurement analysis]")
                 ("import library from \"file:///tmp/lib\" at \"v1\" as lib"
                  "import \"file:///tmp/lib\" at \"v1\" as lib")
                 ("do f with [duration at elapsed of information] into period of information"
                  "do f with [duration at information.elapsed] into information.period")))])
    (define actual (compact (car pair)))
    ;; Compare lexical content while allowing whitespace changes.
    (define (tokens s) (regexp-match* #px"\"(?:[^\"\\\\]|\\\\.)*\"|[^\\s\\[\\]().]+|[\\[\\]().]" s))
    (check-equal? (tokens actual) (tokens (cadr pair)) (car pair)))
  (define unchanged
    "#lang sciencelogo\n; set x to 3\nx = \"period of trial\"\n#| outer #| inner |# end |#\nprint ((x))\n")
  (check-equal? (compact unchanged) unchanged)
  (define with-comments
    "set x ; assignment\n to period #| selected field |# of trial\n")
  (define normalized (normalize-source with-comments #:source 'example))
  (check-true (string-contains? (normalized-source-text normalized) "; assignment\n"))
  (check-true (string-contains? (normalized-source-text normalized) "#| selected field |#"))
  (define location
    (normalized-source-origin normalized
                              (add1 (caar (regexp-match-positions #rx"trial" (normalized-source-text normalized))))))
  (check-equal? (source-origin-source location) 'example))

(module+ test
  (define compact-method
    (string-append
     "workflow \"Equivalence\"\nabout \"Keep 'set' and 'of' as documentation text.\"\n"
     "interface Timing [version \"1\" must [duration unit = \"seconds\"]]\n"
     "performer observer [name = \"Observer\"]\nresource timings [path = \"timings.csv\"]\n"
     "to estimate-period :duration :swings [about \"Divide duration by swing count.\" output :duration / :swings]\n"
     "trial = Timing.[duration = 20]\ntrial += [swings = 10]\n"
     "do estimate-period trial.duration trial.swings as period\nprint period\n"
     "values = [1 2]\nvalues.[2] = 3\nvalues += [4 5]\nprint values\n"
     "revised = values.[1 = 9]\nprint revised\nprint values\n"
     "for each length in range 0.25 to 1 step 0.25 [print length]\n"
     "counter = 0\nwhile counter < 2 [counter += 1]\n"
     "repeat 2 [print counter]\nrepeat [counter += 1] until counter >= 4\n"
     "if counter == 4 [print \"four\"] else if counter != 4 [print \"other\"] else [print \"else\"]\n"
     "if trial is Timing and not (notes in trial) [print trial.unit]\n"
     "hypothesis shorter-swing [text = \"A smaller swing has a shorter period\"]\n"
     "hypotheses.shorter-swing += conclusion answer [text = \"Not supported\"]\n"
     "print hypotheses.shorter-swing.conclusions.answer.text\n"
     "qualified = 2 u [declared = [timing = [estimate = 0.1]]]\nprint qualified.u.declared.timing.estimate\n"
     "stage prepare\nstage measure\nmust stages in order [prepare measure]\nmust do estimate-period\n"))
  (define verbose-method
    (string-append
     "workflow \"Equivalence\"\nabout \"Keep 'set' and 'of' as documentation text.\"\n"
     "interface Timing [version \"1\" must [duration set unit to \"seconds\"]]\n"
     "performer observer [set name to \"Observer\"]\nresource timings [set path to \"timings.csv\"]\n"
     "to estimate-period :duration :swings [about \"Divide duration by swing count.\" output :duration / :swings]\n"
     "set trial to Timing with [set duration to 20]\nupdate trial with [set swings to 10]\n"
     "do estimate-period duration of trial swings of trial as period\nprint period\n"
     "set values to [1 2]\nset [2] of values to 3\nupdate values with [4 5]\nprint values\n"
     "set revised to values with [set 1 to 9]\nprint revised\nprint values\n"
     "for each length in range from 0.25 to 1 with step 0.25 [print length]\n"
     "set counter to 0\nwhile counter is less than 2 [update counter with 1]\n"
     "repeat 2 times [print counter]\nrepeat [update counter with 1] until counter is at least 4\n"
     "if counter equals 4 then [print \"four\"] else if counter does not equal 4 then [print \"other\"] else [print \"else\"]\n"
     "if is trial a Timing and not (is notes in trial) then [print unit of trial]\n"
     "hypothesis shorter-swing [set text to \"A smaller swing has a shorter period\"]\n"
     "update hypotheses.shorter-swing with conclusion answer [set text to \"Not supported\"]\n"
     "print text of hypotheses.shorter-swing.conclusions.answer\n"
     "set qualified to 2 with uncertainty [set declared to [set timing to [set estimate to 0.1]]]\n"
     "print estimate of qualified.u.declared.timing\n"
     "start stage prepare\nstart stage measure\nmust do stages in order [prepare measure]\nmust do estimate-period\n"))
  (check-equal? (datum verbose-method) (datum compact-method))
  (check-equal? (run verbose-method) (run compact-method))
  (check-equal? (compact (compact verbose-method)) (compact verbose-method))
  (check-equal? (datum "set trial to [duration = 20 set swings to 10]\nperiod = trial.duration / swings of trial\nprint period\n")
                (datum "trial = [duration = 20 swings = 10]\nperiod = trial.duration / trial.swings\nprint period\n"))
  (define paired-compact
    (string-append
     "performer observer []\nto estimate :duration :swings [output :duration / :swings]\n"
     "stage measure by observer from state [information = [elapsed = 20 swings = 10 period = unknown]]\n"
     "do estimate with [duration at information.elapsed swings at information.swings] into information.period\n"
     "end stage with state [information = [elapsed = 20 swings = 10 period = unknown]]\n"))
  (define paired-verbose
    (string-append
     "performer observer []\nto estimate :duration :swings [output :duration / :swings]\n"
     "start stage measure by observer from state [set information to [set elapsed to 20 set swings to 10 set period to unknown]]\n"
     "do estimate with [duration at elapsed of information swings at swings of information] into period of information\n"
     "end stage with state [set information to [set elapsed to 20 set swings to 10 set period to unknown]]\n"))
  (check-equal? (datum paired-verbose) (datum paired-compact))
  (check-equal? (datum "interface Timing [must [duration is a number set unit to \"s\"]]\n")
                (datum "interface Timing [must [duration is number unit = \"s\"]]\n"))
  (check-equal? (datum "interface Timing [must [set duration to unknown number]]\n")
                (datum "interface Timing [must [duration = unknown number]]\n"))
  (check-equal? (datum "to read-clock :sample [output time of :sample.clock]\n")
                (datum "to read-clock :sample [output :sample.clock.time]\n"))
  (check-equal? (run "set trial to [period = 2]\nprint (((period) of trial))\n") "2\n")
  (check-equal? (datum "set x to (((2 equals 2)))\n")
                (datum "x = (((2 == 2)))\n"))
  ;; Shortcuts continue to obey compact validation.
  (check-exn #rx"output belongs inside" (lambda () (datum "output period of trial\n")))
  (check-exn #rx"unknown result missing" (lambda () (datum "set result to missing\n")))
  (check-exn #rx"comparison cannot be chained" (lambda () (datum "if 1 is less than 2 is less than 3 then []\n")))
  (check-exn #rx"containing path dotted" (lambda () (compact "set x to period of trial of experiment\n")))
  (check-exn #rx"final field or bracket selection" (lambda () (compact "set x to ([period = 2]) of trial\n")))
  (check-equal? (run "values = [1 2]\nupdate values with [3 4]\nprint values.[3].[2]\n") "4\n")
  (check-equal? (run "values = [1 2]\nset values to values with [set 2 to 3]\nprint values.[2]\n") "3\n")
  (check-exn #rx"update a qualified value" (lambda () (run "set x to 2 with uncertainty []\nupdate x with 1\n")))
  ;; Alias words remain names outside the forms where they act as markers.
  (check-equal? (run "times = 2\nthen = true\nupdate = 3\nto echo :x [output :x]\ndo echo update as result\nrepeat times [if then [print result]]\n")
                "3\n3\n")
  (define located
    (normalize-source "; α\nset result to missing\n" #:source 'original #:line 7 #:column 0 #:position 20))
  (define missing-position
    (add1 (caar (regexp-match-positions #rx"missing" (normalized-source-text located)))))
  (define missing-origin (normalized-source-origin located missing-position))
  (check-equal? (source-origin-line missing-origin) 8)
  (check-equal? (source-origin-column missing-origin) 14)
  (check-equal? (source-origin-position missing-origin) (+ 20 (caar (regexp-match-positions #rx"missing" "; α\nset result to missing\n"))))
  (check-equal? (source-origin-span (normalized-source-origin located (add1 (string-length (normalized-source-text located))))) 0)
  (with-source "; α\nset result to missing\n"
    (lambda (path)
      (check-exn
       (lambda (error)
         (and (exn:fail:read? error)
              (= (srcloc-line (car (exn:fail:read-srclocs error))) 3)
              (= (srcloc-column (car (exn:fail:read-srclocs error))) 14)))
       (lambda () (parse-sciencelogo-file path))))))

(module+ test
  (check-equal?
   (datum "interface Protocol [must [method = unknown text trials] if is method in [\"manual\"] then [must [count is a number]] else if method equals unknown then [notes] else [must [device]] for each trial in trials [must [trial.period is a number]]]\n")
   (datum "interface Protocol [must [method = unknown text trials] if method in [\"manual\"] [must [count is number]] else if method == unknown [notes] else [must [device]] for each trial in trials [must [trial.period is number]]]\n"))
  (check-equal?
   (datum "resource timings [set url to \"https://example.org/timings.csv\"]\nset elapsed to elapsed of timings\nset period of timings to elapsed\n")
   (datum "resource timings [url = \"https://example.org/timings.csv\"]\nelapsed = timings.elapsed\ntimings.period = elapsed\n"))
  (check-equal? (run "set trial to [set clock to [time = 1]]\nset time of trial.clock to 2\nprint time of trial.clock\n") "2\n")
  (check-equal? (run "set grid to [[1 2] [3 4]]\nprint [2] of grid.[1]\nprint count of grid\n") "2\n2\n")
  (check-equal? (datum "set x to (1 + 2) * 3\n") (datum "x = (1 + 2) * 3\n"))
  (check-equal? (datum "if is (1 + 2) in [3 4] and true then []\n")
                (datum "if (1 + 2) in [3 4] and true []\n"))
  (define preserved-source
    "#lang sciencelogo\n; keep set and of\nset wording to \"set x to 2; #| untouched |#\"\nset x to (((2 equals 2))) #| outer #| inner |# end |#\n")
  (define preserved (compact preserved-source))
  (check-true (string-contains? preserved "\"set x to 2; #| untouched |#\""))
  (check-true (string-contains? preserved "; keep set and of\n"))
  (check-true (string-contains? preserved "#| outer #| inner |# end |#"))
  (check-equal? (length (regexp-match* #rx"[(]" preserved)) 3)
  (check-equal? (length (regexp-match* #rx"[)]" preserved)) 3)
  (check-equal? (compact preserved) preserved)
  ;; Both an included workflow and a versioned Git library are normalized.
  (define directory (make-temporary-file "sciencelogo-normalization-repos~a" 'directory))
  (define (git root . arguments)
    (parameterize ([current-output-port (open-output-string)] [current-error-port (open-output-string)])
      (unless (apply system* (find-executable-path "git") "-C" (path->string root) arguments)
        (error 'normalization-tests "Git fixture failed"))))
  (with-git-fixture
    void
    (lambda ()
      (define library (build-path directory "library"))
      (define workflow (build-path directory "workflow"))
      (for ([root (list library workflow)])
        (make-directory root)
        (git root "init" "--initial-branch=main"))
      (display-to-file
       "#lang sciencelogo\nlibrary hello-world [interface Timing [must [set duration to 2]] to greeting [output \"Hello, world!\"]]\n"
       (build-path library "library.rkt"))
      (git library "add" "library.rkt")
      (git library "-c" "user.name=ScienceLogo Tests" "-c" "user.email=tests@example.invalid"
           "commit" "--quiet" "-m" "Define verbose library")
      (git library "tag" "v1")
      (display-to-file
       "#lang sciencelogo\nset trial to hello.Timing with []\nprint duration of trial\n"
       (build-path workflow "method.rkt"))
      (define entry (build-path workflow "entry.rkt"))
      (display-to-file
       (format "#lang sciencelogo\nimport library from ~s at \"v1\" as hello\ninclude \"method.rkt\"\ndo hello.greeting as message\nprint message\n"
               (format "file://~a" library))
       entry)
      (check-equal? (with-output-to-string (lambda () (dynamic-require entry #f))) "2\nHello, world!\n"))
    (lambda () (delete-directory/files directory))))
