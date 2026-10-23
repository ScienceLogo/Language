#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "verbose-syntax"]{Compact and verbose syntax}

ScienceLogo accepts compact, verbose, and mixed source with the same
@tt{#lang sciencelogo} header. A normalizer converts the spellings to compact
source before the compact parser resolves names and applies language checks.
Both spellings describe the same workflow and preserve its existing constraints.
Source conversion accepts compact, verbose, or mixed input and produces either
output form. A file needs no label identifying its input syntax.

Use the @bold{Compact} and @bold{Verbose} tabs on examples to choose a
spelling. The choice applies to the other examples and is remembered across
pages. When both versions are identical, the code appears once without tabs.

@code-example|{
to estimate-period :duration :swings [
  output :duration / :swings
]
set trial to [set duration to 20 set swings to 10]
do estimate-period duration of trial swings of trial as period
print period
}|

The example prints @tt{2}. Procedure definitions, @tt{:inputs}, @tt{do},
@tt{as}, and @tt{output} keep their familiar spelling.

@section{Values and nested access}

@(tabular #:style 'boxed
  (list
   (list (bold "Compact") (bold "Verbose"))
   (list (tt "period = 2") (tt "set period to 2"))
   (list (tt "trial.period") (tt "period of trial"))
   (list (tt "experiment.trial.period") (tt "period of experiment.trial"))
   (list (tt "trial.period = 2") (tt "set period of trial to 2"))
   (list (tt "trials.[2]") (tt "[2] of trials"))
   (list (tt "trials.[1 3]") (tt "[1 3] of trials"))
   (list (tt "trial.[period unit]") (tt "[period unit] of trial"))
   (list (tt "trials.[2] = 3") (tt "set [2] of trials to 3"))
   (list (tt "target += value") (tt "update target with value"))
   (list (tt "trial.[period = 2]") (tt "trial with [set period to 2]"))
   (list (tt "Timing.[duration = 20]") (tt "Timing with [set duration to 20]"))
   (list (tt "period u [...]") (tt "period with uncertainty [...]"))))

Only the final access becomes @tt{of}. The container keeps its dotted path:
write @tt{period of experiment.trial}. The rule also applies to procedure
inputs, stage locations, @tt{count of trials}, and @tt{u of period}.
Qualified procedure and interface names, such as @tt{tools.Timing}, keep
their existing names.

Within object brackets, @tt{set field to value} supplies a field.
Within an interface, it supplies a default. The same spelling creates or
updates a local value at command position.

@tt{update target with value} is exactly @tt{target += value}. On a number,
it adds; on a record, it merges fields; on a proposition, it adds a named child.
On a list, it appends one complete item. List replacement uses @tt{=} or
@tt{set ... to ...} on an indexed position:

@code-example|{
set values to [1 2]
set [2] of values to 3    ; values is now [1 3]
update values with [4 5]  ; values is now [1 3 [4 5]]
}|

A standalone multi-field update can be written by assigning a changed value
back to the same name:

@code-example|{
trial.[unit = "minutes" duration = 3]
}|

@section{Conditions and control flow}

@(tabular #:style 'boxed
  (list
   (list (bold "Compact") (bold "Verbose"))
   (list (tt "a == b") (tt "a equals b"))
   (list (tt "a != b") (tt "a does not equal b"))
   (list (tt "a < b") (tt "a is less than b"))
   (list (tt "a <= b") (tt "a is at most b"))
   (list (tt "a > b") (tt "a is greater than b"))
   (list (tt "a >= b") (tt "a is at least b"))
   (list (tt "a xor b") (tt "a exclusive or b"))
   (list (tt "value in values") (tt "is value in values"))
   (list (tt "notes in trial") (tt "is notes in trial"))
   (list (tt "period is number") (tt "is period a number"))
   (list (tt "trial is Timing") (tt "is trial a Timing"))
   (list (tt "range a to b step c") (tt "range from a to b with step c"))
   (list (tt "repeat 3 [...]") (tt "repeat 3 times [...]"))
   (list (tt "if condition [...]") (tt "if condition then [...]"))
   (list (tt "else if condition [...]") (tt "else if condition then [...]"))))

Arithmetic operators, @tt{and}, @tt{or}, @tt{not}, @tt{else}, @tt{while},
@tt{for each ... in ...}, and @tt{repeat [...] until ...} stay shared.
Operator precedence follows the @secref["compact-grammar"] rules.

@section{Stages, interfaces, and libraries}

@(tabular #:style 'boxed
  (list
   (list (bold "Compact") (bold "Verbose"))
   (list (tt "stage measure") (tt "start stage measure"))
   (list (tt "end stage with state [...]") (tt "end stage with state [...]"))
   (list (tt "measure implement Protocol.measurement")
         (tt "measure implements Protocol.measurement"))
   (list (tt "affects measurement analysis") (tt "measurement affects analysis"))
   (list (tt "must stages in order [prepare measure]")
         (tt "must do stages in order [prepare measure]"))
   (list (tt "duration is number") (tt "duration is a number"))
   (list (tt "duration = unknown number") (tt "set duration to unknown number"))
   (list (tt "import \"URL\" at \"version\" as tools")
         (tt "import library from \"URL\" at \"version\" as tools"))))

The type declaration @tt{duration is a number} belongs inside an interface;
@tt{is duration a number} asks a question about a value.
@tt{interface}, @tt{version}, @tt{extends}, @tt{must}, @tt{must do name},
@tt{include}, @tt{library}, @tt{performer}, @tt{resource}, @tt{hypothesis},
@tt{assumption}, @tt{conclusion}, @tt{workflow}, and @tt{about} stay shared.
Their fields can use either assignment spelling at every depth.
The existing @tt{implements "file.rkt" as alias [provide ... by "..."]}
file-reference form also stays shared.

A paired stage can use @tt{start stage measure by observer from state [...]};
its closing @tt{end stage with state [...]} remains identical.
Its calls use the existing input and output words, with optional @tt{of}
access for locations:

@code-example|{
do estimate-period with [
  duration at elapsed of information
  swings at swing-count of information
] into period of information
}|

Both entry and exit state objects remain required for paired stages.
Performer rules, state restrictions, interface requirements, and resource-only
external data references apply equally to compact and verbose spellings.

@section{Mixed source and preservation}

Either spelling can appear inside the other:

@verbatim|{
set trial to [duration = 20 set swings to 10]
period = trial.duration / swings of trial
if period >= 2 and not (is notes in trial) then [
  print period
]
}|

Names remain unquoted and case-sensitive, with optional capitalization and
hyphen conventions. Quoted strings, Markdown in @tt{about}, @tt{;} comments,
and nested @tt{#| ... |#} comments retain their contents. Every explicit
parenthesis group is retained, including redundant and nested groups.
The normalizer also retains a source location for each output character, so
reader diagnostics can refer to the original source.

The
@hyperlink[(source-file-url "spec/verbose-syntax.md")]{verbose syntax specification}
gives the complete equivalences and preservation contract.

@section{Convert a source file}

Choose the output syntax on the command line:

@verbatim|{
racket -l sciencelogo/translate -- --to verbose investigation.rkt
racket -l sciencelogo/translate -- --to compact investigation.rkt
}|

The converter writes the converted source to standard output. Either command
accepts a compact, verbose, or mixed file. To save the result, redirect it to
a different file:

@verbatim|{
racket -l sciencelogo/translate -- --to verbose investigation.rkt > investigation-verbose.rkt
}|

Each invocation converts one file. Source dependency paths and qualified
definition names retain their references. In verbose output, containing paths
stay dotted and shared forms keep their spelling, as specified above.
The converter retains code indentation and line endings while normalizing
spacing between tokens. Repeated conversion does not accumulate indentation
or spaces. Strings, comments, and existing parentheses are retained.

@section{Source conversion API for applications}

@index["sciencelogo/normalize"]
@index["sciencelogo/translate"]

The Racket API is @tt{sciencelogo/normalize}; @tt{sciencelogo/translate}
also exports it. @tt{normalize-source} produces compact source.
@tt{translate-source} accepts either spelling or any mixture and requires
@tt{#:to 'compact} or @tt{#:to 'verbose} to choose the output.

@verbatim|{
(require sciencelogo/normalize)

(define result
  (translate-source "period = 2\n" #:to 'verbose #:source 'example))

(normalized-source-text result)
(normalized-source-origin result 1)
}|

The output text in this example is @tt{"set period to 2\n"}.
Both functions accept a string, with optional @tt{#:source},
@tt{#:line}, @tt{#:column}, and @tt{#:position}. Defaults are @tt{#f},
@tt{1}, @tt{0}, and @tt{1}. Both return a @tt{normalized-source} whose
@tt{text} is source in the selected output syntax and whose @tt{origins}
is an immutable vector.

@tt{normalized-source-origin} accepts that result and a one-based position
in its text, including the position immediately after its last character.
It returns a @tt{source-origin} with @tt{source}, @tt{line}, @tt{column},
@tt{position}, and @tt{span}. Lines and positions start at one; columns
start at zero. The EOF entry has span zero. Verbose conversion retains the
original locations through both passes: normalization to compact, then
generation of verbose source. Other SDKs can use the same sequence and keep
one compact parser and set of language checks. Conversion recognizes source
forms; parsing, name resolution, and language checks determine whether the
result is a valid workflow.
