#lang racket/base

(require rackunit
         racket/file
         racket/port
         racket/system)

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

(define (with-library-repo use)
  (define repo (make-temporary-file "sciencelogo-library-test-~a" 'directory))
  (dynamic-wind
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
            "library \"hello-world\" [\n"
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
            "to echo :name [output :name]\n")
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
  (dynamic-wind
    void
    (lambda ()
      (git a "init" "--initial-branch=main")
      (git b "init" "--initial-branch=main")
      (git c "init" "--initial-branch=main")
      (write-library b
                     (string-append
                      "#lang sciencelogo\n"
                      "library \"base\" [\n"
                      "  to message :name [stage \"Review\" output :name]\n"
                      "]\n"))
      (commit-and-tag b "v1.0.0")
      (make-directory (build-path a "greetings"))
      (call-with-output-file (build-path a "greetings" "welcome.rkt")
        (lambda (out)
          (display
           (string-append
            "#lang sciencelogo\n"
            "to welcome :name [\n"
            "  stage \"Review\"\n"
            "  do b.message :name as greeting\n"
            "  print greeting\n"
            "]\n")
           out)))
      (write-library a
                     (format
                      (string-append
                       "#lang sciencelogo\n"
                       "library \"wrapper\" [\n"
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
                       "library \"consumer\" [\n"
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
                       "library \"consumer\" [\n"
                       "  import ~s at \"v1.0.0\" as a\n"
                       "  to indirect :name [do a.b.message :name as note print note]\n"
                       "]\n")
                      a-url))
      (commit-and-tag c "v-leak")
      (write-library b
                     (format
                      (string-append
                       "#lang sciencelogo\n"
                       "library \"base\" [\n"
                       "  import ~s at \"v-cycle\" as a\n"
                       "  to message :name [output :name]\n"
                       "]\n")
                      a-url))
      (commit-and-tag b "v-cycle")
      (write-library a
                     (format
                      (string-append
                       "#lang sciencelogo\n"
                       "library \"wrapper\" [\n"
                       "  import ~s at \"v-cycle\" as b\n"
                       "  to welcome :name [do b.message :name as greeting print greeting]\n"
                       "]\n")
                      b-url))
      (commit-and-tag a "v-cycle")
      (use a-url b-url c-url))
    (lambda () (delete-directory/files base))))

(module+ test
  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "workflow \"Timing records\"\n"
     "interface \"Timing\" [duration unit = \"seconds\"]\n"
     "set trial to Timing but [duration = 2]\n"
     "print unit of trial\n"
     "set revised to trial but [unit = \"minutes\"]\n"
     "print unit of revised\n"
     "print unit of trial\n"
     "set explicit to [duration = unknown unit = \"seconds\"]\n"
     "print duration of explicit\n"))
   "seconds\nminutes\nseconds\nunknown\n")
  (check-equal?
   (output-of
    (string-append "#lang sciencelogo\n"
                   "interface \"Timing\" [duration unit = \"seconds\"]\n"
                   "set trial to Timing but [duration = 2]\n"
                   "print unit of trial\n"))
   "seconds\n")
  (check-exn
   #rx"Timing is missing field duration"
   (lambda ()
     (output-of
      (string-append "#lang sciencelogo\nworkflow \"Timing\"\n"
                     "interface \"Timing\" [duration unit = \"seconds\"]\n"
                     "set trial to Timing but [unit = \"minutes\"]\n"))))
  (check-exn
   #rx"duplicate interface field duration"
   (lambda ()
     (output-of
      "#lang sciencelogo\ninterface \"Timing\" [duration duration]\n")))
  (check-equal?
   (output-of
    "#lang sciencelogo\ndo greet\nto greet [print \"Hello\"]\n")
   "Hello\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "set lengths to range 0.25 to 1.00 step 0.25\n"
     "for each length in lengths [print length]\n"
     "for each length in lengths [if length >= 0.75 [print length]]\n"))
   "0.25\n0.5\n0.75\n1\n0.75\n1\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "set stop to 0.3\n"
     "print range 0.1 to stop step 0.1\n"
     "print range 0.1 to 0.35 step 0.1\n"
     "print range 1 to 1 step -1\n"))
   "[0.1 0.2 0.3]\n[0.1 0.2 0.3]\n[1]\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "set lengths to range 1 to 3 step 1\n"
     "for each length in lengths [print length]\n"
     "do [set lengths to [4 5]]\n"
     "for each length in lengths [print length]\n"))
   "1\n2\n3\n4\n5\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "do sweep 1\n"
     "to sweep :limit [\n"
     "  set values to range 0 to :limit step 0.5\n"
     "  for each value in values [print value]\n"
     "]\n"))
   "0\n0.5\n1\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "set values to [1 2 true \"ready\"]\n"
     "repeat 2 [print values]\n"
     "if 1 > 2 [print \"wrong\"] "
     "else if 2 = 2 [print \"matched\"] "
     "else [print \"wrong\"]\n"
     "set continue to true\n"
     "while continue [print \"once\" set continue to false]\n"
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
     "set steps to range 0 to (2 + 2) step 1 + 1\n"
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
     "print not 1 = 2\n"
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
     "set attempts to 0\n"
     "while attempts < 3 and not (attempts = 2) ["
     "set attempts to attempts + 1 print attempts]\n"
     "do add 1 + 2 (3 * 4) as total\n"
     "print total\n"
     "to add :a :b [output :a + :b]\n"))
   "1\n2\n15\n")

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "set trial to [temperature = 0.5 + 0.3 "
     "prompt = \"tell me the capital of Peru\"]\n"
     "print temperature of trial\n"
     "print temperature of trial + 0.2\n"
     "print prompt of trial\n"
     "print trial\n"
     "do echo trial as copy\n"
     "print temperature of copy\n"
     "if trial = [prompt = \"tell me the capital of Peru\" "
     "temperature = 0.8] [print \"same fields\"]\n"
     "set nested to [measurement = [unit = \"C\"]]\n"
     "print unit of measurement of nested\n"
     "set x to 1 set y to 2 print [x y]\n"
     "print [[1 2] [3 4]]\n"
     "print [(1 = 1)]\n"
     "to echo :item [output :item]\n"))
   (string-append
    "0.8\n1\ntell me the capital of Peru\n"
    "[prompt = \"tell me the capital of Peru\" temperature = 0.8]\n"
    "0.8\nsame fields\nC\n[1 2]\n[[1 2] [3 4]]\n[true]\n"))

  (check-exn
   #rx"duplicate field temperature"
   (lambda ()
     (output-of
      "#lang sciencelogo\nset trial to [temperature = 0.8 temperature = 0.9]\n")))

  (check-exn
   #rx"missing field period"
   (lambda ()
     (output-of
      "#lang sciencelogo\nset trial to [temperature = 0.8]\nprint period of trial\n")))

  (check-exn
   #rx"field temperature needs a named-field value"
   (lambda ()
     (output-of
      "#lang sciencelogo\nset trial to [0.8]\nprint temperature of trial\n")))

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "set human to [species = \"human\" gender = \"unspecified\"]\n"
     "set john to human but [gender = \"male\"]\n"
     "set earlier to john\n"
     "set john to john but [height = 193]\n"
     "print gender of human\n"
     "print gender of earlier\n"
     "print height of john\n"
     "print earlier\n"
     "print height of (john but [height = 194])\n"
     "print height of john\n"))
   (string-append
    "unspecified\nmale\n193\n"
    "[gender = \"male\" species = \"human\"]\n"
    "194\n193\n"))

  (check-exn
   #rx"but needs a named-field value"
   (lambda ()
     (output-of "#lang sciencelogo\nprint 1 but [height = 193]\n")))

  (check-exn
   #rx"but needs named fields in"
   (lambda ()
     (output-of "#lang sciencelogo\nprint [height = 170] but [193]\n")))

  (check-exn
   #rx"duplicate field height"
   (lambda ()
     (output-of
      "#lang sciencelogo\nprint [height = 170] but [height = 193 height = 194]\n")))

  (check-exn
   #rx"condition is undetermined"
   (lambda ()
     (output-of
      "#lang sciencelogo\nif [value = unknown] = [value = unknown] [print \"same\"]\n")))

  (check-equal?
   (output-of
    (string-append
     "#lang sciencelogo\n"
     "set lengths to [0.25 0.5 0.75]\n"
     "print item 1 of lengths\n"
     "print item 3 of lengths\n"
     "set position to 2\n"
     "print item position of lengths\n"
     "print item 1 + 1 of lengths\n"
     "set grid to [[10 20] [30 40]]\n"
     "print item 2 of grid\n"
     "print item 2 of item 1 of grid\n"
     "for each item in [1 2] [print item]\n"
     "set trial to [item = \"label\"]\n"
     "print item of trial\n"
     "print item unknown of lengths\n"))
   "0.25\n0.75\n0.5\n0.5\n[30 40]\n20\n1\n2\nlabel\nunknown\n")

  (check-exn
   #rx"item index must be a positive integer starting at 1"
   (lambda () (output-of "#lang sciencelogo\nprint item 0 of [1 2]\n")))

  (check-exn
   #rx"item index must be a positive integer starting at 1"
   (lambda () (output-of "#lang sciencelogo\nprint item 1.5 of [1 2]\n")))

  (check-exn
   #rx"item index 3 is outside a list of 2 items"
   (lambda () (output-of "#lang sciencelogo\nprint item 3 of [1 2]\n")))

  (check-exn
   #rx"item needs an ordered list"
   (lambda ()
     (output-of "#lang sciencelogo\nprint item 1 of [temperature = 0.8]\n")))

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

  (check-exn
   #rx"condition is undetermined"
   (lambda () (output-of
               "#lang sciencelogo\nif unknown = false [print \"yes\"] else [print \"no\"]\n")))

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
   #rx"cannot set protected name length"
   (lambda () (output-of
               "#lang sciencelogo\nfor each length in [1] [set length to 2]\n")))

  (check-exn
   #rx"cannot set protected name result"
   (lambda () (output-of
               "#lang sciencelogo\ndo echo 1 as result\nset result to 2\nto echo :x [output :x]\n")))

  (check-exn
   #rx"cannot set protected name x"
   (lambda () (output-of
               "#lang sciencelogo\nto change :x [set x to 2]\n")))

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
       "library \"No workflow title here\" [\n"
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
     "  stage \"Prepare\"\n"
     "  do make-plan as plan\n"
     "  to make-plan [output \"ready\"]\n"
     "  stage \"Review\"\n"
     "  print plan\n"
     "\n"))
   "ready\n")

  (check-exn
   #rx"unknown procedure Review"
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "workflow \"Stages are labels\"\nstage \"Review\" do Review\n"))))

  (check-exn
   #rx"duplicate stage \"Review\""
   (lambda ()
     (output-of
      "#lang sciencelogo\nstage \"Review\" stage \"Review\"\n")))

  (check-exn
   #rx"duplicate stage \"Review\""
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "to prepare [stage \"Review\"]\n"
       "to analyze [stage \"Review\"]\n"))))

  (check-exn
   #rx"duplicate stage \"Review\""
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "library \"Repeated stage\" [\n"
       "  to prepare [stage \"Review\"]\n"
       "  to analyze [stage \"Review\"]\n"
       "]\n"))))

  (check-exn
   #rx"duplicate procedure prepare"
   (lambda ()
     (output-of
      (string-append
       "#lang sciencelogo\n"
       "library \"Repeated procedure\" [\n"
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
     "must stages in order [\"Prepare\" \"Time\"]\n"
     "stage \"Prepare\"\n"
     "stage \"Time\"\n"))
   "")

  (check-exn
   #rx"must stages in order needs at least two stage names"
   (lambda ()
     (output-of
      "#lang sciencelogo\nmust stages in order [\"Prepare\"]\n")))

  (check-exn
   #rx"duplicate required stage"
   (lambda ()
     (output-of
      "#lang sciencelogo\nmust stages in order [\"Time\" \"Time\"]\n")))

  (check-exn
   #rx"must belongs directly in a workflow file"
   (lambda ()
     (output-of
      "#lang sciencelogo\ndo [must stages in order [\"Prepare\" \"Time\"]]\n")))

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
