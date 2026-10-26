#lang racket/base

(require "git-fixture.rkt"
         rackunit
         racket/file
         racket/path
         racket/port
         racket/system
         "../assessor.rkt"
         "../private/reader.rkt")

(define (with-source source use)
  (define path (make-temporary-file "sciencelogo-~a.rkt"
                                    #:base-dir (current-directory)))
  (call-with-output-file path
    (lambda (out) (display source out))
    #:exists 'truncate)
  (dynamic-wind
    void
    (lambda () (use path))
    (lambda () (delete-file path))))

(define (output-of source)
  (with-source source
    (lambda (path)
      (with-output-to-string
        (lambda () (dynamic-require path #f))))))

(define (with-workflow-repo use)
  (define directory (make-temporary-file "sciencelogo-workflow-~a" 'directory))
  (with-git-fixture
    void
    (lambda ()
      (unless (zero? (parameterize ([current-output-port (open-output-string)]
                                    [current-error-port (open-output-string)])
                       (system*/exit-code (find-executable-path "git")
                                          "-C" (path->string directory)
                                          "init" "--initial-branch=main")))
        (error 'with-workflow-repo "could not initialize Git repository"))
      (define (write-source relative content)
        (define path (build-path directory relative))
        (make-directory* (path-only path))
        (call-with-output-file path (lambda (out) (display content out))
          #:exists 'truncate)
        path)
      (use directory write-source))
    (lambda () (delete-directory/files directory))))

(define (with-library-repo use)
  (define repo (make-temporary-file "sciencelogo-library-test-~a" 'directory))
  (with-git-fixture
    void
    (lambda ()
      (define (git . args)
        (define status
          (parameterize ([current-output-port (open-output-string)]
                         [current-error-port (open-output-string)])
            (apply system*/exit-code (find-executable-path "git")
                   "-C" (path->string repo) args)))
        (unless (zero? status) (error 'with-library-repo "Git command failed")))
      (git "init" "--initial-branch=main")
      (make-directory* (build-path repo "greetings"))
      (make-directory* (build-path repo "shared"))
      (make-directory* (build-path repo "tools"))
      (call-with-output-file (build-path repo "library.rkt")
        (lambda (out)
          (display
           (string-append
            "#lang sciencelogo\n"
            "library hello-world [\n"
            "  include \"greetings/hello.rkt\"\n"
            "  include \"tools/echo.rkt\"\n"
            "]\n")
           out)))
      (call-with-output-file (build-path repo "greetings" "hello.rkt")
        (lambda (out)
          (display
           (string-append
            "#lang sciencelogo\n"
            "include \"../shared/message.rkt\"\n"
            "to say-hello [do greet]\n")
           out)))
      (call-with-output-file (build-path repo "shared" "message.rkt")
        (lambda (out)
          (display
           (string-append
            "#lang sciencelogo\n"
            "to greet [print \"Hello, world!\"]\n")
           out)))
      (call-with-output-file (build-path repo "tools" "echo.rkt")
        (lambda (out)
          (display
           (string-append
            "#lang sciencelogo\n"
            "interface Timing [must [duration unit = \"seconds\"] notes "
            "documentation [must [uncertainty unit = \"seconds\"]]]\n"
            "to echo :name [output :name]\n"
            "to make-trial :duration [\n"
            "  trial = Timing.[duration = :duration]\n"
            "  output trial\n"
            "]\n")
           out)))
      (git "add" ".")
      (git "-c" "user.name=ScienceLogo Tests"
           "-c" "user.email=tests@example.invalid"
           "commit" "--quiet" "-m" "Add hello-world library")
      (git "tag" "v1.0.0")
      (check-equal?
       (with-output-to-string
         (lambda () (dynamic-require (build-path repo "library.rkt") #f))) "")
      (call-with-output-file (build-path repo "shared" "message.rkt")
        (lambda (out)
          (display
           (string-append
            "#lang sciencelogo\n"
            "include \"../greetings/hello.rkt\"\n"
            "to greet [print \"Hello, world!\"]\n")
           out))
        #:exists 'truncate)
      (git "add" "shared/message.rkt")
      (git "-c" "user.name=ScienceLogo Tests"
           "-c" "user.email=tests@example.invalid"
           "commit" "--quiet" "-m" "Add include cycle")
      (git "tag" "v-cycle")
      (call-with-output-file (build-path repo "greetings" "hello.rkt")
        (lambda (out)
          (display
           (string-append
            "#lang sciencelogo\n"
            "include \"../../outside.rkt\"\n"
            "to say-hello [do greet]\n")
           out))
        #:exists 'truncate)
      (git "add" "greetings/hello.rkt")
      (git "-c" "user.name=ScienceLogo Tests"
           "-c" "user.email=tests@example.invalid"
           "commit" "--quiet" "-m" "Add escaping include path")
      (git "tag" "v-escape")
      (git "switch" "--quiet" "-c" "other")
      (call-with-output-file (build-path repo "other.txt")
        (lambda (out) (display "Only on another branch\n" out)))
      (git "add" "other.txt")
      (git "-c" "user.name=ScienceLogo Tests"
           "-c" "user.email=tests@example.invalid"
           "commit" "--quiet" "-m" "Add off-main commit")
      (git "tag" "off-main")
      (git "switch" "--quiet" "main")
      (use (format "file://~a" (path->string repo))))
    (lambda () (delete-directory/files repo))))

(define (with-dependent-libraries use)
  (define base (make-temporary-file "sciencelogo-dependencies-~a" 'directory))
  (define a (build-path base "a"))
  (define b (build-path base "b"))
  (define c (build-path base "c"))
  (make-directory a)
  (make-directory b)
  (make-directory c)
  (define a-url (format "file://~a" (path->string a)))
  (define b-url (format "file://~a" (path->string b)))
  (define c-url (format "file://~a" (path->string c)))
  (define (git repo . args)
    (define status
      (parameterize ([current-output-port (open-output-string)]
                     [current-error-port (open-output-string)])
        (apply system*/exit-code (find-executable-path "git")
               "-C" (path->string repo) args)))
    (unless (zero? status) (error 'with-dependent-libraries "Git command failed")))
  (define (write-library repo content)
    (call-with-output-file (build-path repo "library.rkt")
      (lambda (out) (display content out))
      #:exists 'truncate))
  (define (commit-and-tag repo tag)
    (git repo "add" ".")
    (git repo "-c" "user.name=ScienceLogo Tests"
         "-c" "user.email=tests@example.invalid"
         "commit" "--quiet" "-m" tag)
    (git repo "tag" tag))
  (with-git-fixture
    void
    (lambda ()
      (git a "init" "--initial-branch=main")
      (git b "init" "--initial-branch=main")
      (git c "init" "--initial-branch=main")
      (write-library b
                     (string-append
                      "#lang sciencelogo\n"
                      "library base [\n"
                      "  interface Timing [must [duration unit = \"seconds\"] notes]\n"
                      "  to message :name [stage Review output :name]\n"
                      "]\n"))
      (commit-and-tag b "v1.0.0")
      (make-directory (build-path a "greetings"))
      (call-with-output-file (build-path a "greetings" "welcome.rkt")
        (lambda (out)
          (display
           (string-append
            "#lang sciencelogo\n"
            "interface TimedPlace [extends b.Timing must [place]]\n"
            "to welcome :name [\n"
            "  stage Review\n"
            "  do b.message :name as greeting\n"
            "  print greeting\n"
            "]\n"
            "to make-trial [\n"
            "  trial = TimedPlace.[duration = 2 place = \"lab\"]\n"
            "  output trial\n"
            "]\n")
           out)))
      (write-library a
                     (format
                      (string-append
                       "#lang sciencelogo\n"
                       "library wrapper [\n"
                       "  import ~s at \"v1.0.0\" as b\n"
                       "  include \"greetings/welcome.rkt\"\n"
                       "]\n")
                      b-url))
      (commit-and-tag a "v1.0.0")
      (check-equal?
       (with-output-to-string
         (lambda () (dynamic-require (build-path a "library.rkt") #f))) "")
      (write-library c
                     (format
                      (string-append
                       "#lang sciencelogo\n"
                       "library consumer [\n"
                       "  import ~s at \"v1.0.0\" as a\n"
                       "  import ~s at \"v1.0.0\" as b\n"
                       "  to direct :name [\n"
                       "    do a.welcome :name\n"
                       "    do b.message \"Separate\" as note\n"
                       "    print note\n"
                       "  ]\n"
                       "]\n")
                      a-url b-url))
      (commit-and-tag c "v1.0.0")
      (write-library c
                     (format
                      (string-append
                       "#lang sciencelogo\n"
                       "library consumer [\n"
                       "  import ~s at \"v1.0.0\" as a\n"
                       "  to indirect :name [do a.b.message :name as note print note]\n"
                       "]\n")
                      a-url))
      (commit-and-tag c "v-leak")
      (write-library b
                     (format
                      (string-append
                       "#lang sciencelogo\n"
                       "library base [\n"
                       "  import ~s at \"v-cycle\" as a\n"
                       "  to message :name [output :name]\n"
                       "]\n")
                      a-url))
      (commit-and-tag b "v-cycle")
      (write-library a
                     (format
                      (string-append
                       "#lang sciencelogo\n"
                       "library wrapper [\n"
                       "  import ~s at \"v-cycle\" as b\n"
                       "  to welcome :name [do b.message :name as greeting print greeting]\n"
                       "]\n")
                      b-url))
      (commit-and-tag a "v-cycle")
      (use a-url b-url c-url))
    (lambda () (delete-directory/files base))))

(module+ test
  (with-workflow-repo
   (lambda (directory write-source)
     (write-source "shared/plan.rkt"
                   "#lang sciencelogo\nto plan [output \"ready\"]\n")
     (write-source "shared/timing.rkt"
                   "#lang sciencelogo\ninterface Timing [must [duration]]\n")
     (write-source "methods/method.rkt"
                   (string-append
                    "#lang sciencelogo\n"
                    "interface Timing [must [duration unit = \"seconds\"]]\n"
                    "stage Prepare\n"
                    "include \"../shared/plan.rkt\"\n"
                    "included-trial = [duration = 2]\n"
                    "included-trial implement \"../shared/timing.rkt\"\n"))
     (define entry
       (write-source "entry.rkt"
                     (string-append
                      "#lang sciencelogo\nworkflow \"Split workflow\"\n"
                      "include \"methods/method.rkt\"\n"
                      "trial = Timing.[duration = 2]\n"
                      "trial implement Timing\n"
                      "do plan as message\nprint message\n")))
     (check-equal? (with-output-to-string (lambda () (dynamic-require entry #f)))
                   "ready\n")
     (check-equal?
      (map condition-check-outcome (assessment-checks (assess-file entry)))
      '(satisfied satisfied))
     (write-source "entry.rkt"
                   (string-append
                    "#lang sciencelogo\n"
                    "include \"methods/method.rkt\"\n"
                    "include \"methods/../methods/method.rkt\"\n"))
     (check-exn #rx"duplicate include"
                (lambda () (parse-sciencelogo-file entry)))
     (write-source "entry.rkt"
                   "#lang sciencelogo\ninclude \"../outside.rkt\"\n")
     (check-exn #rx"include path escapes the workflow repository"
                (lambda () (parse-sciencelogo-file entry)))
     (write-source "entry.rkt"
                   "#lang sciencelogo\ninclude \"methods/method.rkt\"\n")
     (write-source "shared/plan.rkt"
                   "#lang sciencelogo\ninclude \"../entry.rkt\"\n")
     (check-exn #rx"include cycle"
                (lambda () (parse-sciencelogo-file entry)))))

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\nworkflow \"Combined timing\"\n"
     "interface TimedTrial [extends Timing extends Site must [duration unit = \"minutes\"]]\n"
     "interface Timing [must [duration unit = \"seconds\"]]\n"
     "interface Site [must [place]]\n"
     "trial = TimedTrial.[duration = 2 place = \"lab\"]\n"
     "print trial.unit\nprint trial.place\n"))
   "minutes\nlab\n")
  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "interface Combined [extends First extends Second must [shared = \"resolved\"]]\n"
     "interface First [must [shared = \"first\" a]]\n"
     "interface Second [must [shared = \"second\" b]]\n"
     "record = Combined.[a = 1 b = 2]\n"
     "print record.shared\n"))
   "resolved\n")
  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "interface Combined [extends First extends Second]\n"
     "interface First [must [unit = \"seconds\"]]\n"
     "interface Second [must [unit = \"seconds\"]]\n"
     "trial = Combined.[]\n"
     "print trial.unit\n"))
   "seconds\n")
  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "interface Leaf [extends Middle must [c]]\n"
     "interface Middle [extends Base must [b]]\n"
     "interface Base [must [a]]\n"
     "value = Leaf.[a = 1 b = 2 c = 3]\n"
     "print value.a\n"))
   "1\n")
  (check-exn
   #rx"duplicate parent interface Base"
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "interface Leaf [extends Base extends Base]\n"
       "interface Base [must [a]]\n"))))
  (check-exn
   #rx"standalone interfaces cannot extend"
   (lambda ()
     (output-of "#lang sciencelogo\ninterface Leaf [extends Base]\n")))
  (check-exn
   #rx"TimedTrial is missing field place"
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "interface TimedTrial [extends Timing extends Site]\n"
       "interface Timing [must [duration]]\n"
       "interface Site [must [place]]\n"
       "trial = TimedTrial.[duration = 2]\n"))))
  (for ([source (in-list
                 (list
                  (string-append
                   "#lang sciencelogo\n"
                   "interface Combined [extends First extends Second]\n"
                   "interface First [must [shared = \"first\"]]\n"
                   "interface Second [must [shared = \"second\"]]\n")
                  (string-append
                   "#lang sciencelogo\n"
                   "interface One [extends Two]\n"
                   "interface Two [extends One]\n")
                  (string-append
                   "#lang sciencelogo\n"
                   "interface One [extends Missing]\n"
                   "trial = One.[value = 1]\n")))]
        [message (in-list '("conflicting inherited field shared"
                            "interface extension cycle"
                            "unknown parent interface Missing"))])
    (check-exn
     (lambda (error)
       (and (exn:fail:read? error)
            (regexp-match? (regexp message) (exn-message error))))
     (lambda () (output-of source))))

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "workflow \"Timing records\"\n"
     "interface Timing [must [duration unit = \"seconds\"]]\n"
     "trial = Timing.[duration = 2]\n"
     "print trial.unit\n"
     "revised = trial.[unit = \"minutes\"]\n"
     "print revised.unit\n"
     "print trial.unit\n"
     "explicit = [duration = unknown unit = \"seconds\"]\n"
     "print explicit.duration\n"))
   "seconds\nminutes\nseconds\nunknown\n")
  (check-equal?
   (output-of
    (string-append "#lang sciencelogo\n"
                   "interface Timing [must [duration unit = \"seconds\"]]\n"
                   "trial = Timing.[duration = 2]\n"
                   "print trial.unit\n"))
   "seconds\n")
  (check-exn
   #rx"Timing is missing field duration"
   (lambda ()
     (output-of
      (string-append "#lang sciencelogo\nworkflow \"Timing\"\n"
                     "interface Timing [must [duration unit = \"seconds\"]]\n"
                     "trial = Timing.[unit = \"minutes\"]\n"))))
  (check-exn
   #rx"duplicate interface field duration"
   (lambda ()
     (output-of
      "#lang sciencelogo\ninterface Timing [must [duration duration]]\n")))
  (check-equal?
   (output-of
    "#lang sciencelogo\ndo greet\nto greet [print \"Hello\"]\n")
   "Hello\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "do greet count = 1 print count\n"
     "to greet []\n"))
   "1\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "count = 1 do echo (count == 1) as matches print matches\n"
     "to echo :flag [output :flag]\n"))
   "true\n")

  (check-equal?
   (output-of "#lang sciencelogo\nset count to 1\nprint count\n")
   "1\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "lengths = range 0.25 to 1.00 step 0.25\n"
     "for each length in lengths [print length]\n"
     "for each length in lengths [if length >= 0.75 [print length]]\n"))
   "0.25\n0.5\n0.75\n1\n0.75\n1\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "stop = 0.3\n"
     "print range 0.1 to stop step 0.1\n"
     "print range 0.1 to 0.35 step 0.1\n"
     "print range 1 to 1 step -1\n"))
   "[0.1 0.2 0.3]\n[0.1 0.2 0.3]\n[1]\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "lengths = range 1 to 3 step 1\n"
     "for each length in lengths [print length]\n"
     "do [lengths = [4 5]]\n"
     "for each length in lengths [print length]\n"))
   "1\n2\n3\n4\n5\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "do sweep 1\n"
     "to sweep :limit [\n"
     "  values = range 0 to :limit step 0.5\n"
     "  for each value in values [print value]\n"
     "]\n"))
   "0\n0.5\n1\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "values = [1 2 true \"ready\"]\n"
     "repeat 2 [print values]\n"
     "if 1 > 2 [print \"wrong\"] "
     "else if 2 == 2 [print \"matched\"] "
     "else [print \"wrong\"]\n"
     "continue = true\n"
     "while continue [print \"once\" continue = false]\n"
     "repeat [print \"once\"] until true\n"))
   "[1 2 true ready]\n[1 2 true ready]\nmatched\nonce\nonce\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "for each outer in [1 2] ["
     "for each inner in range 3 to 1 step -1 [print inner]]\n"
     "to decide :answer [output :answer]\n"
     "repeat [do decide true as finished] until finished\n"))
   "3\n2\n1\n3\n2\n1\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "print 1 + 2 * 3\n"
     "print (1 + 2) * 3\n"
     "print 1 / 4 + 0.5\n"
     "print 5 - 2 - 1\n"
     "print - 2 * 3\n"
     "print 1 / 3\n"
     "steps = range 0 to (2 + 2) step 1 + 1\n"
     "print steps\n"
     "print [1 + 2 4]\n"))
   "7\n9\n0.75\n2\n-6\n1/3\n[0 2 4]\n[3 4]\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "print true or false and false\n"
     "print true xor true\n"
     "print true xor false\n"
     "print not true or false\n"
     "print not 1 == 2\n"
     "print true and not false\n"
     "print false and unknown\n"
     "print true or unknown\n"
     "print unknown xor true\n"
     "print true xor true and false\n"
     "print true or true xor true\n"
     "print false and (1 / 0)\n"
     "print true or (1 / 0)\n"))
   "true\nfalse\ntrue\nfalse\ntrue\ntrue\nfalse\ntrue\nunknown\ntrue\ntrue\nfalse\ntrue\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "attempts = 0\n"
     "while attempts < 3 and not (attempts == 2) ["
     "attempts = attempts + 1 print attempts]\n"
     "do add 1 + 2 (3 * 4) as total\n"
     "print total\n"
     "to add :a :b [output :a + :b]\n"))
   "1\n2\n15\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "trial = [temperature = 0.5 + 0.3 "
     "prompt = \"tell me the Peru.capital\"]\n"
     "print trial.temperature\n"
     "print trial.temperature + 0.2\n"
     "print trial.prompt\n"
     "print trial\n"
     "do echo trial as copy\n"
     "print copy.temperature\n"
     "if trial == [prompt = \"tell me the Peru.capital\" "
     "temperature = 0.8] [print \"same fields\"]\n"
     "nested = [measurement = [unit = \"C\"]]\n"
     "print nested.measurement.unit\n"
     "x = 1 y = 2 print [x y]\n"
     "print [[1 2] [3 4]]\n"
     "print [(1 == 1)]\n"
     "to echo :item [output :item]\n"))
   (string-append
    "0.8\n1\ntell me the Peru.capital\n"
    "[prompt = \"tell me the Peru.capital\" temperature = 0.8]\n"
    "0.8\nsame fields\nC\n[1 2]\n[[1 2] [3 4]]\n[true]\n"))

  (check-exn
   #rx"duplicate field temperature"
   (lambda ()
     (output-of
      "#lang sciencelogo\ntrial = [temperature = 0.8 temperature = 0.9]\n")))

  (check-exn
   #rx"missing field period"
   (lambda ()
     (output-of
      "#lang sciencelogo\ntrial = [temperature = 0.8]\nprint trial.period\n")))

  (check-exn
   #rx"field temperature needs a named-field value"
   (lambda ()
     (output-of
      "#lang sciencelogo\ntrial = [0.8]\nprint trial.temperature\n")))

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "human = [species = \"human\" gender = \"unspecified\"]\n"
     "john = human.[gender = \"male\"]\n"
     "earlier = john\n"
     "john = john.[height = 193]\n"
     "print human.gender\n"
     "print earlier.gender\n"
     "print john.height\n"
     "print earlier\n"
     "print (john.[height = 194]).height\n"
     "print john.height\n"))
   (string-append
    "unspecified\nmale\n193\n"
    "[gender = \"male\" species = \"human\"]\n"
    "194\n193\n"))

  (check-exn
   #rx"unsupported command but"
   (lambda ()
     (output-of "#lang sciencelogo\nprint 1 but [height = 193]\n")))

  (check-exn
   #rx"record selection needs a field name"
   (lambda ()
     (output-of "#lang sciencelogo\nprint [height = 170].[193]\n")))

  (check-exn
   #rx"duplicate field height"
   (lambda ()
     (output-of
      "#lang sciencelogo\nprint [height = 170].[height = 193 height = 194]\n")))

  (check-equal?
   (output-of
    "#lang sciencelogo\nif [value = unknown] == [value = unknown] [print \"same\"]\n")
   "same\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "lengths = [0.25 0.5 0.75]\n"
     "print lengths.[1]\n"
     "print lengths.[3]\n"
     "position = 2\n"
     "print lengths.[position]\n"
     "print lengths.[1 + 1]\n"
     "grid = [[10 20] [30 40]]\n"
     "print grid.[2]\n"
     "print grid.[1].[2]\n"
     "for each item in [1 2] [print item]\n"
     "trial = [item = \"label\"]\n"
     "print trial.item\n"
     "print lengths.[unknown]\n"))
   "0.25\n0.75\n0.5\n0.5\n[30 40]\n20\n1\n2\nlabel\nunknown\n")

  (check-exn
   #rx"list position must be between 1 and 2"
   (lambda () (output-of "#lang sciencelogo\nprint [1 2].[0]\n")))

  (check-exn
   #rx"list position must be between 1 and 2"
   (lambda () (output-of "#lang sciencelogo\nprint [1 2].[1.5]\n")))

  (check-exn
   #rx"list position must be between 1 and 2"
   (lambda () (output-of "#lang sciencelogo\nprint [1 2].[3]\n")))

  (check-exn
   #rx"record selection needs a field name"
   (lambda ()
     (output-of "#lang sciencelogo\nprint [temperature = 0.8].[1]\n")))

  (check-exn
   #rx"division by zero"
   (lambda () (output-of "#lang sciencelogo\nprint 1 / 0\n")))

  (check-exn
   #rx"Boolean operator needs true or false"
   (lambda () (output-of "#lang sciencelogo\nif 1 and true [print \"yes\"]\n")))

  (check-exn
   #rx"comparison cannot be chained"
   (lambda () (output-of "#lang sciencelogo\nif 1 < 2 < 3 [print \"yes\"]\n")))

  (check-exn
   #rx"condition is undetermined"
   (lambda () (output-of "#lang sciencelogo\nif unknown xor true [print \"yes\"]\n")))

  (check-exn
   #rx"condition is undetermined"
   (lambda () (output-of
               "#lang sciencelogo\nif unknown [print \"yes\"] else [print \"no\"]\n")))

  (check-equal?
   (output-of "#lang sciencelogo\nif unknown == false [print \"yes\"] else [print \"no\"]\n")
   "no\n")

  (check-exn
   #rx"range step must not be zero"
   (lambda () (output-of
               "#lang sciencelogo\nfor each x in range 1 to 2 step 0 [print x]\n")))

  (check-exn
   #rx"range step must move toward the end"
   (lambda () (output-of
               "#lang sciencelogo\nfor each x in range 1 to 2 step -1 [print x]\n")))

  (check-exn
   #rx"unknown result length"
   (lambda () (output-of
               "#lang sciencelogo\nfor each length in [1] [print length]\nprint length\n")))

  (check-exn
   #rx"cannot assign protected name length"
   (lambda () (output-of
               "#lang sciencelogo\nfor each length in [1] [length = 2]\n")))

  (check-exn
   #rx"cannot assign protected name result"
   (lambda () (output-of
               "#lang sciencelogo\ndo echo 1 as result\nresult = 2\nto echo :x [output :x]\n")))

  (check-exn
   #rx"cannot assign protected name x"
   (lambda () (output-of
               "#lang sciencelogo\nto change :x [x = 2]\n")))

  (check-exn
   #rx"workflow title appears only once"
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "workflow \"First title\"\n"
       "workflow \"Second title\"\n"))))

  (check-exn
   #rx"workflow title is not allowed in a library"
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "library No-workflow-title-here [\n"
       "  workflow \"Forbidden\"\n"
       "]\n"))))

  (check-exn
   #rx"workflow title appears only once at the top"
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "to greeting [output \"Hello\"]\n"
       "workflow \"Too late\"\n"))))

  (check-exn
   #rx"workflow title appears only once at the top"
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "import \"file:///not-used\" at \"v1\" as example\n"
       "workflow \"After import\"\n"))))

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "workflow \"A staged plan\"\n"
     "  stage Prepare\n"
     "  do make-plan as plan\n"
     "  to make-plan [output \"ready\"]\n"
     "  stage Review\n"
     "  print plan\n"
     "\n"))
   "ready\n")

  (check-exn
   #rx"unknown procedure Review"
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "workflow \"Stages are labels\"\nstage Review do Review\n"))))

  (check-exn
   #rx"duplicate stage \"Review\""
   (lambda ()
     (output-of
      "#lang sciencelogo\nstage Review stage Review\n")))

  (check-exn
   #rx"duplicate stage \"Review\""
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "to prepare [stage Review]\n"
       "to analyze [stage Review]\n"))))

  (check-exn
   #rx"duplicate stage \"Review\""
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "library Repeated-stage [\n"
       "  to prepare [stage Review]\n"
       "  to analyze [stage Review]\n"
       "]\n"))))

  (check-exn
   #rx"duplicate procedure prepare"
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "library Repeated-procedure [\n"
       "  to prepare []\n"
       "  to prepare []\n"
       "]\n"))))

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "workflow \"Pendulum period\"\n"
     "  do [do first print \"last\"]\n"
     "  to first [print \"first\" do second]\n"
     "  to second [print \"second\"]\n"
     "\n"))
   "first\nsecond\nlast\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "#| outer #| nested |# comment |#\n"
     "workflow \"Notes\"\n"
     "  ; the brackets in the string are ordinary text\n"
     "  print \"period [s]\"\n"
     "\n"))
   "period [s]\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "workflow \"Call requirement\"\n"
     "  must do compare-periods\n"
     "  print \"requirement declared\"\n"
     "  to compare-periods [print \"called\"]\n"
     "\n"))
   "requirement declared\n")

  (check-exn
   #rx"must belongs directly in a workflow file"
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "workflow \"Invalid\"\ndo [must do compare-periods] "
       "to compare-periods []\n"))))

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "workflow \"Ordered stages\"\n"
     "must stages in order [Prepare Time]\n"
     "stage Prepare\n"
     "stage Time\n"))
   "")

  (check-exn
   #rx"must stages in order needs at least two stage names"
   (lambda ()
     (output-of
      "#lang sciencelogo\nmust stages in order [Prepare]\n")))

  (check-exn
   #rx"duplicate required stage"
   (lambda ()
     (output-of
      "#lang sciencelogo\nmust stages in order [Time Time]\n")))

  (check-exn
   #rx"must belongs directly in a workflow file"
   (lambda ()
     (output-of
      "#lang sciencelogo\ndo [must stages in order [Prepare Time]]\n")))

  (check-exn
   #rx"expected a procedure name"
   (lambda ()
     (output-of
      "#lang sciencelogo\nworkflow \"Invalid\"\nto must []\n")))

  (define output-before-error (open-output-string))
  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"unknown procedure missing" (exn-message e))))
   (lambda ()
     (parameterize ([current-output-port output-before-error])
       (output-of
        (string-append
         "#lang sciencelogo\n"
         "workflow \"Invalid\"\nprint \"must not run\" do missing\n")))))
  (check-equal? (get-output-string output-before-error) "")

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"duplicate procedure observe" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "workflow \"Invalid\"\nto observe [] to observe []\n"))))

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"recursive call" (exn-message e))))
   (lambda ()
     (output-of
     (string-append
       "#lang sciencelogo\n"
       "workflow \"Invalid\"\nto first [do second] to second [do first]\n"))))

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"expected ] before end of file" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "workflow \"Invalid\"\ndo [print \"incomplete\"\n"))))

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "workflow \"Pendulum labels\"\n"
     "  do make-note \"Pendulum P1\" as note\n"
     "  print note\n"
     "  to make-note :pendulum [\n"
     "    do echo :pendulum as inner\n"
     "    output inner\n"
     "  ]\n"
     "  to echo :item [output :item]\n"
     "\n"))
   "Pendulum P1\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "workflow \"Timing day\"\n"
     "  do choose-day \"Pendulum P1\" \"Monday\" as day\n"
     "  print day\n"
     "  to choose-day :pendulum :day [\n"
     "    print :pendulum\n"
     "    do [output :day]\n"
     "  ]\n"
     "\n"))
   "Pendulum P1\nMonday\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "workflow \"Nested results\"\n"
     "  do echo \"outer\" as outer\n"
     "  do [print outer do echo \"first\" as local print local]\n"
     "  do [do echo \"second\" as local print local]\n"
     "  print outer\n"
     "  to echo :value [output :value]\n"
     "\n"))
   "outer\nfirst\nsecond\nouter\n")

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"duplicate result outer" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "workflow \"Invalid\"\n"
       "  do echo \"outer\" as outer\n"
       "  do [do echo \"inner\" as outer]\n"
       "  to echo :value [output :value]\n"
       "\n"))))

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"wrong number of inputs for echo" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "workflow \"Invalid\"\ndo echo to echo :item [output :item]\n"))))

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"unknown result note" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "workflow \"Invalid\"\n"
       "  do [do echo \"inside\" as note]\n"
       "  print note\n"
       "  to echo :item [output :item]\n"
       "\n"))))

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"procedure no-result has no output" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "workflow \"Invalid\"\n"
       "  do no-result as note\n"
       "  to no-result [print \"not returned\"]\n"
       "\n"))))

  (check-exn
   (lambda (e)
     (and (exn:fail:read? e)
          (regexp-match? #rx"procedure name cannot contain a dot" (exn-message e))))
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "workflow \"Invalid\"\nto local.name []\n"))))

  (with-library-repo
   (lambda (url)
     (check-equal?
      (output-of
       (format
        (string-append
         "#lang sciencelogo\n"
         "workflow \"Use a library\"\n"
         "import ~s at \"v1.0.0\" as hello\n"
         "  do hello.say-hello\n"
         "  do hello.echo \"Researcher\" as name\n"
         "  print name\n"
         "\n")
        url))
      "Hello, world!\nResearcher\n")
     (check-equal?
      (output-of
       (format
        (string-append
         "#lang sciencelogo\n"
         "import ~s at \"v1.0.0\" as hello\n"
         "interface TimedPlace [extends hello.Timing must [place]]\n"
         "local = TimedPlace.[duration = 2 place = \"lab\"]\n"
         "local implement hello.Timing\n"
         "do hello.make-trial 3 as remote\n"
         "remote implement hello.Timing\n"
         "print local.unit\n"
         "print remote.duration\n")
        url))
      "seconds\n3\n")
     (with-source
      (format
       (string-append
        "#lang sciencelogo\nimport ~s at \"v1.0.0\" as hello\n"
        "details = hello.Timing.documentation.[uncertainty = [estimate = unknown]]\n"
        "details implement hello.Timing.documentation\n"
        "print details.unit\n") url)
      (lambda (path)
        (check-equal? (with-output-to-string (lambda () (dynamic-require path #f)))
                      "seconds\n")
        (check-equal? (assessment-findings (assess-file path)) '())))
     (with-source
      (format
       (string-append
        "#lang sciencelogo\n"
        "import ~s at \"v1.0.0\" as hello\n"
        "trial = [unit = \"seconds\"]\n"
        "trial implement hello.Timing\n")
       url)
      (lambda (path)
        (check-equal?
         (map condition-check-outcome
              (assessment-checks (assess-file path)))
         '(violated))))
     (check-exn
      (lambda (e)
        (and (exn:fail:read? e)
             (regexp-match? #rx"could not resolve library tag or commit"
                            (exn-message e))))
      (lambda ()
        (output-of
         (format
          (string-append
           "#lang sciencelogo\n"
           "import ~s at \"main\" as hello\n"
           "do hello.say-hello\n")
          url))))
     (check-exn
      (lambda (e)
        (and (exn:fail:read? e)
             (regexp-match? #rx"could not verify library revision is on main"
                            (exn-message e))))
      (lambda ()
        (output-of
         (format
          (string-append
           "#lang sciencelogo\n"
           "import ~s at \"off-main\" as hello\n"
           "do hello.say-hello\n")
          url))))
     (check-exn
      (lambda (e)
        (and (exn:fail:read? e)
             (regexp-match? #rx"include cycle through greetings/hello.rkt"
                            (exn-message e))))
      (lambda ()
        (output-of
         (format
          (string-append
           "#lang sciencelogo\n"
           "import ~s at \"v-cycle\" as hello\n"
           "do hello.say-hello\n")
          url))))
     (check-exn
      (lambda (e)
        (and (exn:fail:read? e)
             (regexp-match? #rx"include path escapes the library repository"
                            (exn-message e))))
      (lambda ()
        (output-of
         (format
          (string-append
           "#lang sciencelogo\n"
           "import ~s at \"v-escape\" as hello\n"
           "do hello.say-hello\n")
          url))))))

  (with-dependent-libraries
   (lambda (a-url b-url c-url)
     (check-equal?
      (output-of
       (format
        (string-append
         "#lang sciencelogo\n"
         "import ~s at \"v1.0.0\" as a\n"
         "trial = a.TimedPlace.[duration = 3 place = \"field\"]\n"
         "trial implement a.TimedPlace\n"
         "do a.make-trial as other\n"
         "print trial.unit\n"
         "print other.place\n")
        a-url))
      "seconds\nlab\n")
     (check-exn
      #rx"a library dependency is private"
      (lambda ()
        (output-of
         (format
          (string-append
           "#lang sciencelogo\n"
           "import ~s at \"v1.0.0\" as a\n"
           "trial = a.b.Timing.[duration = 2]\n")
          a-url))))
     (check-equal?
      (output-of
       (format
        (string-append
         "#lang sciencelogo\n"
         "import ~s at \"v1.0.0\" as a\n"
         "do a.welcome \"Scientist\"\n")
        a-url))
      "Scientist\n")
     (check-exn
      (lambda (e)
        (and (exn:fail:read? e)
             (regexp-match? #rx"unknown procedure b.message" (exn-message e))))
      (lambda ()
        (output-of
         (format
          (string-append
           "#lang sciencelogo\n"
           "import ~s at \"v1.0.0\" as a\n"
           "do b.message \"Scientist\"\n")
          a-url))))
     (check-exn
      (lambda (e)
        (and (exn:fail:read? e)
             (regexp-match? #rx"a library dependency is private"
                            (exn-message e))))
      (lambda ()
        (output-of
         (format
          (string-append
           "#lang sciencelogo\n"
           "import ~s at \"v1.0.0\" as a\n"
           "do a.b.message \"Scientist\"\n")
          a-url))))
     (check-equal?
      (output-of
       (format
        (string-append
         "#lang sciencelogo\n"
         "import ~s at \"v1.0.0\" as a\n"
         "import ~s at \"v1.0.0\" as b\n"
         "  do a.welcome \"Scientist\"\n"
         "  do b.message \"Researcher\" as name\n"
         "  print name\n"
         "\n")
        a-url b-url))
      "Scientist\nResearcher\n")
     (check-equal?
      (output-of
       (format
        (string-append
         "#lang sciencelogo\n"
         "import ~s at \"v1.0.0\" as c\n"
         "do c.direct \"Scientist\"\n")
        c-url))
      "Scientist\nSeparate\n")
     (check-exn
      (lambda (e)
        (and (exn:fail:read? e)
             (regexp-match? #rx"a library dependency is private"
                            (exn-message e))))
      (lambda ()
        (output-of
         (format
          (string-append
           "#lang sciencelogo\n"
           "import ~s at \"v-leak\" as c\n"
           "do c.indirect \"Scientist\"\n")
          c-url))))
     (check-exn
      (lambda (e)
        (and (exn:fail:read? e)
             (regexp-match? #rx"library import cycle through"
                            (exn-message e))))
      (lambda ()
        (output-of
         (format
          (string-append
           "#lang sciencelogo\n"
           "import ~s at \"v-cycle\" as a\n"
           "do a.welcome \"Scientist\"\n")
          a-url)))))))

(module+ test
  (check-equal?
   (output-of "#lang sciencelogo\ntrial = [time = 1]\nprint time of trial\n")
   "1\n")
  (check-exn exn:fail?
             (lambda ()
               (output-of "#lang sciencelogo\ntrials = [1 2]\nprint item 1 of trials\n")))
  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "measurement = [clock.time = \"11:00\" clock.day = \"Tuesday\"]\n"
     "earlier = measurement\n"
     "measurement.clock.time = \"12:00\"\n"
     "measurement.[clock.day = \"Wednesday\"]\n"
     "selected = measurement.clock.[time day]\n"
     "print selected\n"
     "print earlier.clock.time\n"
     "trials = [[time = 1] [time = 2]]\n"
     "trials.[2].time = 3\n"
     "trials.[1 = [time = 4] 2 = [time = 5]]\n"
     "print trials.[2].time\n"
     "print trials.[1 2]\n"
     "to show :trial [output :trial.time]\n"
     "do show measurement.clock as answer\n"
     "print answer\n"))
   "[day = \"Wednesday\" time = \"12:00\"]\n11:00\n5\n[[time = 4] [time = 5]]\n12:00\n")
  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "interface Clock [must [clock.time clock.unit = \"seconds\"]]\n"
     "trial = Clock.[clock.time = \"12:00\"]\n"
     "print trial.clock.unit\n"))
   "seconds\n")
  (check-equal?
   (output-of
    "#lang sciencelogo\nperformer researcher [role = \"scientist\"]\nprint researcher.role\n")
   "scientist\n")
  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "interface Base-clock [must [clock.time = \"12:00\"]]\n"
     "interface Extended-clock [extends Base-clock must [clock.unit = \"seconds\"]]\n"
     "trial = Extended-clock.[]\n"
     "print trial.clock.time\n"
     "print trial.clock.unit\n"))
   "12:00\nseconds\n")
  (with-source
   (string-append
    "#lang sciencelogo\n"
    "interface Clock [must [clock.time clock.unit = \"seconds\"]]\n"
    "trial = Clock.[clock.time = \"12:00\"]\n"
    "trial implement Clock\n")
   (lambda (path)
     (check-equal?
      (map condition-check-outcome (assessment-checks (assess-file path)))
      '(satisfied))))
  (with-source
   (string-append
    "#lang sciencelogo\n"
    "interface Clock-fields [must [time unit]]\n"
    "trial = [clock = [time = \"12:00\" unit = \"seconds\"]]\n"
    "trial.clock implement Clock-fields\n")
   (lambda (path)
     (check-equal?
      (map condition-check-outcome (assessment-checks (assess-file path)))
      '(satisfied)))))

(module+ test
  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "interface Timing [must [duration unit = \"seconds\"]]\n"
     "x = Timing.[duration = 2]\n"
     "earlier = x\n"
     "x += [unit = \"minutes\" note = \"hand timed\"]\n"
     "x.duration += 2\n"
     "print x\n"
     "print earlier\n"
     "x += [note = \"rechecked\"]\n"
     "print x.note\n"))
   (string-append
    "[duration = 4 note = \"hand timed\" unit = \"minutes\"]\n"
    "[duration = 2 unit = \"seconds\"]\n"
    "rechecked\n"))
  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "x = [clock = [time = 1 day = \"Monday\"]]\n"
     "x.clock += [time = 2]\n"
     "x.clock.time += 3\n"
     "print x.clock\n"
     "count = 1\n"
     "count += 2\n"
     "print count\n"))
   "[day = \"Monday\" time = 5]\n3\n")
  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "to identity :value [output :value]\n"
     "count = 1\n"
     "do identity count\n"
     "count += 2\n"
     "print count\n"))
   "3\n")
  (with-source
   (string-append
    "#lang sciencelogo\n"
    "interface Timing [must [duration unit]]\n"
    "trial = [duration = 2]\n"
    "trial += [unit = \"seconds\"]\n"
    "trial implement Timing\n")
   (lambda (path)
     (check-equal?
      (map condition-check-outcome (assessment-checks (assess-file path)))
      '(satisfied))))
  (check-exn
   #rx"unknown result x"
   (lambda () (output-of "#lang sciencelogo\nx += [duration = 2]\n")))
  (check-exn
   #rx"missing field duration"
   (lambda ()
     (output-of "#lang sciencelogo\nx = [unit = \"seconds\"]\nx.duration += 2\n")))
  (check-exn
   #rx"arithmetic needs exact numbers"
   (lambda ()
     (output-of "#lang sciencelogo\nx = [duration = \"two\"]\nx.duration += 2\n"))))
