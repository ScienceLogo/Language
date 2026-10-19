#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "assessment"]{Assessment support}

ScienceLogo lets an author declare a few requirements on a written method.
The current assessor checks their @emph{structure}: required calls and stage
order, supplied workflow parts, and record field presence. These checks go
beyond parsing syntax, but they do not show that the work happened or judge
its scientific adequacy. Protocol conformance, bias analysis, uncertainty
analysis, and assessment of observed runs are not built-in checks. Their
applications may use the method information the reader preserves.
@secref["interfaces"] defines the two kinds of interface used here.

@section{Declare a structural check}

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "What the current assessor checks"))
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
including an included workflow file. They declare requirements; they neither
run the named work nor make a scientific claim true. An assessment reports
@tt{satisfied}, @tt{violated}, or @tt{undetermined} for a check. Its outcome
must be read together with what that check actually tests.

@section{Identify required workflow parts}

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
An interface may also declare a bare name for an optional workflow part.
The workflow may provide that part, but its absence does not produce a
missing-part finding. A provision for an undeclared name remains an error.

The current command for inspecting these declarations is:

@verbatim|{
racket -l sciencelogo/assessor -- examples/meta-assessor/method.rkt
racket -l sciencelogo/assessor -- examples/meta-assessor/missing-impact.rkt
}|

The first command reports no structural issues. The second reports missing
@tt{trace-impacts} and marks @tt{report} as affected through a declared
@tt{affects} link. It exits with status 1. Here @tt{affects} records a possible
downstream dependency between required parts; it does not calculate a
scientific impact.

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
stages to appear in that order in the written workflow. At least two
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

@section{Method information available to other tools}

The implemented @hyperlink[(source-file-url "workflow-model.rkt")]{Racket workflow model}
records the written investigation as procedures, activities, named input and
result slots, imports, performers, named data sources and destinations,
interface claims, @tt{must do}
conditions, and typed relations. @tt{read-workflow-model} reads an
investigation file;
@tt{read-interface-model} reads an interface file. Method elements carry
source locations. Explicit state stages retain their entry and exit records;
state calls retain input-location mappings and the return location. A call
links to its procedure with @tt{invokes}; named
results link to their producing and using activities. A sequence retains
command order. Data assignments retain their dotted paths and link to a
declared source or destination with @tt{reads-from} or @tt{writes-to}; see
@secref["resources"]. The assessor checks that each activity and named item
has one containment link to its recorded parent.

@tt{assess-workflow} checks this model; @tt{assess-file} reads the file first.
The returned structural assessment includes condition checks and findings that identify
their targets. For a @tt{require} part, @tt{satisfied} means a matching
@tt{provide} declaration exists. A missing part is @tt{violated}. A
downstream part reached through @tt{affects} is reported as possibly affected,
with an @tt{undetermined} outcome for that impact. This assessment does not
verify the content of a provision or a run.

The @hyperlink[(source-file-url "examples/pendulum-method.rkt")]{pendulum planning example}
can be read into the same model. It returns and prints a timing plan; it does
not time a pendulum. The
@hyperlink[(source-file-url "examples/pendulum-period.md")]{young Galileo design case}
describes measurements and observed run checks that the current language
cannot yet record as run events. The
@hyperlink[(source-file-url "spec/representation.md")]{shared representation
contract} describes what readers in other languages should preserve; it does
not make the Racket assessor an implementation of those future applications.
