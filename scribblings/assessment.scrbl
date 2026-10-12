#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "assessment"]{Assessment}

ScienceLogo can check declared structure in a written workflow. These checks
inspect the method; they do not carry out the work or establish its scientific
adequacy. @secref["interfaces"] defines the two kinds of interface that can
be checked here.

@section{Check forms}

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "Checks"))
   (list (tt "implements \"relative/file.rkt\" as alias [provide part by \"reference\" ...]")
         "Claims how a workflow provides parts required by a separate interface")
   (list (tt "must do procedure")
         "Requires a call along the written method's established paths")
   (list (tt "must stages in order [\"First\" \"Second\" ...]")
         "Requires at least two distinct stage titles in order")
   (list (tt "must record-name implement Interface")
         "Checks a written record against a named interface")
   (list (tt "must record-name implement \"relative/file.rkt\"")
         "Checks a written record against a separate interface file")))

All @tt{implements} and @tt{must} forms belong at workflow top level,
including an included workflow file. They declare checks; they do not run
the named work.

@section{Provide workflow parts}

The @hyperlink[(source-file-url "examples/meta-assessor/method.rkt")]{complete example workflow}
references the example interface shown in @secref["interfaces"] and supplies an
implementation reference for each required part:

@verbatim|{
#lang sciencelogo

workflow "How does ScienceLogo assess ScienceLogo?"
implements "requirements/assessor.rkt" as assessor [
  provide parse by "../../private/reader.rkt"
  provide resolve-libraries by "../../private/reader.rkt"
  provide check-interfaces by "../../assessor.rkt"
  provide trace-impacts by "../../assessor.rkt"
  provide report by "../../assessor.rkt"
]
}|

The interface path is relative to the file containing @tt{implements}.
A @tt{provide} reference is a claim: the assessor does not inspect the named
file or establish that the work exists or is correct. ScienceLogo does not
require every workflow activity to have an author-written name. An interface
may omit @tt{version}; the assessment report identifies the source revision
with a hash and does not compare versions.

Run these examples from an installed checkout:

@verbatim|{
racket -l sciencelogo/assessor -- examples/meta-assessor/method.rkt
racket -l sciencelogo/assessor -- examples/meta-assessor/missing-impact.rkt
}|

The first command reports no structural issues. The second reports missing
@tt{trace-impacts} and marks @tt{report} as affected through a declared
@tt{affects} link. It exits with status 1.

@section{Require a call}

@tt{must do} requires a procedure call on the written method's established
paths. For example:

@verbatim|{
#lang sciencelogo

workflow "How will we compare pendulum periods?"
must do compare-periods
do prepare-comparison
to prepare-comparison [do compare-periods]
to compare-periods []
}|

The assessor reports this condition as satisfied because the workflow calls
@tt{prepare-comparison}, which calls @tt{compare-periods}. A definition alone,
a call inside an unused procedure, or a call only under @tt{if false} or
@tt{repeat 0} does not satisfy it. A call that depends on an unresolved
condition is reported as undetermined. The check resolves literal conditions
and counts; named values and procedure inputs remain unknown. It does not
run the procedure or establish that the work happened.

@section{Require an order of stages}

@tt{must stages in order ["Prepare" "Measure"]} requires the named top-level
stage headers to appear in that order in the written workflow. At least two
distinct titles are required. Other stages may appear between them. The
assessor reports a missing stage or wrong order; a stage inside a procedure
does not count as a top-level stage for this check.

@section{Check a record interface}

@tt{must trial implement Timing} checks whether the written shape of
@tt{trial} contains the fields of the named record interface. A literal
record can satisfy it even if the record was not constructed from @tt{Timing}.
The path form, @tt{must trial implement "interfaces/timing.rkt"}, loads a
separate record interface file relative to the workflow file. See
@secref["interfaces"] for construction, inheritance, defaults, and the
limits of this check when a record's shape is undetermined.

@section{Inspect the method model}

The implemented @hyperlink[(source-file-url "workflow-model.rkt")]{workflow model}
records the written investigation as procedures, activities, named input and
result slots, imports, interface claims, @tt{must do} conditions, and typed
relations. @tt{read-workflow-model} reads an investigation file;
@tt{read-interface-model} reads an interface file. Method elements carry
source locations. A call links to its procedure with @tt{invokes}; named
results link to their producing and using activities. A sequence retains
command order. The assessor checks that each activity and named item has one
containment link to its recorded parent.

@tt{assess-workflow} checks this model; @tt{assess-file} reads the file first.
The returned assessment includes condition checks and findings that identify
their targets. For a @tt{require} part, @tt{satisfied} means a matching
@tt{provide} declaration exists. A missing part is @tt{violated}. A
downstream part reached through @tt{affects} is reported as possibly affected,
with an @tt{undetermined} outcome for that impact. This assessment does not
verify the content of a provision or a run.

The @hyperlink[(source-file-url "examples/pendulum-method.rkt")]{pendulum planning example}
can be read into the same model. It returns and prints a timing plan; it does
not time a pendulum. The
@hyperlink[(source-file-url "examples/pendulum-period.md")]{young Galileo design case}
describes measurements and run checks that the current language cannot yet
express.
