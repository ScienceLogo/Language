#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "assessment"]{Assessment support}

ScienceLogo lets an author declare a few requirements on a written method.
The current assessor checks their @emph{structure}: required calls and stage
order, supplied workflow parts, and record field presence and value requirements. These checks go
beyond parsing syntax, but they do not show that the work happened or judge
its scientific adequacy. Protocol conformance, bias analysis, uncertainty
analysis, and assessment of observed runs are not built-in checks. Their
applications may use the method information the reader preserves.
@secref["interfaces"] defines the shared declaration rules for data fields
and workflow parts.

@section{Map workflow parts to interface requirements}

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "What the current assessor checks"))
   (list (tt "\"Stage title\" implement Protocol.part")
         "Maps a declared stage to an interface part")
   (list (tt "procedure implement Protocol.part")
         "Maps a procedure to an interface part")
   (list (tt "information.period.u implement Protocol.documentation.uncertainty")
         "Identifies the state value addressing a particular requirement")
   (list (tt "must do procedure")
         "Requires a call along the written method's established paths")
   (list (tt "must stages in order [\"First\" \"Second\" ...]")
         "Requires at least two distinct stage titles in order")
   (list (tt "record-name implement Interface")
         "Checks a written record against a named interface")
   (list (tt "record-name implement \"relative/file.rkt\"")
         "Checks a written record against a separate interface file")))

Use @tt{implement} directly, without @tt{must}. In an interface,
@tt{must [...]} declares requirements. In a workflow, @tt{implement} identifies
the stage, procedure, or value addressing a requirement. It does not call a
procedure, change state, or establish scientific conformity.

Mappings can appear at workflow top level, inside procedures, or inside
stages. Stage and procedure references may precede their definitions; a value
must be available where it is referenced. The reader checks the references
and preserves the mapping and its source location for inspection.
@tt{must do} and @tt{must stages in order} remain top-level declarations.
An assessment reports
@tt{satisfied}, @tt{violated}, or @tt{undetermined} for a check. Its outcome
must be read together with what that check actually tests.

@section{Map a pendulum stage and its data}

The @hyperlink[(source-file-url "examples/protocol-mapping.rkt")]{runnable mapping example}
uses the protocol from @secref["interfaces"]. The stage addresses its measurement
part, and the uncertainty description addresses its nested documentation requirement:

@verbatim|{
#lang sciencelogo

workflow "Document a pendulum measurement"
interface "Pendulum-protocol" [
  version "1"
  must [measurement documentation [must [uncertainty] notes]]
  additional-measurements
]
performer researcher [kind = "human"]

"Timing" implement Pendulum-protocol.measurement

stage "Timing" by researcher from state [
  information = [period = 2 u [declared = [timing = [estimate = 0.1 unit = "seconds"]]]]
]
  information.period.u implement Pendulum-protocol.documentation.uncertainty
end stage with state [
  information = [period = 2 u [declared = [timing = [estimate = 0.1 unit = "seconds"]]]]
]
}|

This example declares its interface in the same file, so it also runs from
an installed package. In a workflow repository, the existing @tt{include}
rule can load a local interface. A library interface uses its existing import
alias, such as @tt{prot.Pendulum-protocol.measurement}. The interface's version
and source revision identify the protocol being referenced.

A mapping to a parent claims its required descendants. A mapping to one child
identifies that child and its parent as present; it does not claim siblings.
Optional children remain optional. If an optional group is supplied, its own
required children apply. A stage or procedure can reference the whole
interface. Several workflow parts may address the same requirement, and
one part may address several requirements.

The current command for inspecting these declarations is:

@verbatim|{
racket -l sciencelogo/assessor -- examples/protocol-mapping.rkt
}|

This reports no structural issues: the required mapping declarations are
present. It does not establish that a measurement occurred, that its
uncertainty is adequate, or that the protocol was scientifically followed.
Applications can inspect the mapped stage, state, and performer to assess
those questions.

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

@tt{trial implement Timing} checks whether the written shape of
@tt{trial} contains the fields of the named record interface. A literal
record can satisfy it even if the record was not constructed from @tt{Timing}.
The path form, @tt{trial implement "interfaces/timing.rkt"}, loads a
separate record interface file relative to the workflow file. See
@secref["interfaces"] for construction, inheritance, defaults, and the
limits of this check when a record's shape is undetermined.

An interface may also state value requirements such as
@tt{must [swing-count > 10 unit == "seconds"]}. For values available in a
written record, the structural checker evaluates these expressions as well
as field presence. A false requirement is violated; an unresolved requirement
is undetermined. Construction fills defaults with @tt{=}; an equality
requirement written with @tt{==} supplies no default.

An interface can use @tt{for each} to apply requirements to every item of
a written list. The structural record check examines the known items and
identifies missing fields by their positions, such as
@tt{measurements.[2].period.u}. Empty lists have no items to check;
unknown collections or needed values leave checks undetermined.
@secref["interface-list-requirements"] explains the declaration form.

For workflow mappings, the model retains the expressions and their guards.
The current mapping checker resolves literal expressions; requirements
depending on mapped workflow values remain undetermined. Other applications
can use the recorded values and mappings to assess them.
List requirements retain their local item name, collection expression,
guard, and a nested interface model of the body, including source locations.

@section{Method information available to other tools}

The implemented @hyperlink[(source-file-url "workflow-model.rkt")]{Racket workflow model}
records the written investigation as procedures, activities, named input and
result slots, imports, performers, named data sources and destinations,
interface mappings, @tt{must do}
conditions, and typed relations. @tt{read-workflow-model} reads an
investigation file;
@tt{read-interface-model} reads an interface file. Method elements carry
source locations. Explicit state stages retain their entry and exit records;
state calls retain input-location mappings and the return location. A call
links to its procedure with @tt{invokes}; named
results link to their producing and using activities. A sequence retains
command order. Data assignments retain their dotted paths and link to a
declared source or destination with @tt{reads-from} or @tt{writes-to}; see
@secref["resources"]. The assessor checks that each activity, named item, and mapping
has one containment link to its recorded parent. A mapping retains whether its
subject is a stage, procedure, or value, its resolved reference or value path,
the interface version and source revision, and the nested requirement path.
It also retains the declaration location and scope. Multiple mappings remain
separate records.

@tt{assess-workflow} checks this model; @tt{assess-file} reads the file first.
The returned structural assessment includes condition checks and findings that identify
their targets. For a required workflow part, @tt{satisfied} means a matching
mapping declaration exists. A missing part is @tt{violated}. A
downstream part reached through @tt{affects} is reported as possibly affected,
with an @tt{undetermined} outcome for that impact. This assessment does not
verify the content of a provision or a run.

The older file-reference form,
@tt{implements "relative/file.rkt" as alias [provide part by "reference"]},
remains supported for references written as text. The
@hyperlink[(source-file-url "examples/meta-assessor/README.md")]{assessor self-description}
exercises that form and its missing-part reports. Direct @tt{implement}
mappings identify workflow stages, procedures, and values themselves.

The @hyperlink[(source-file-url "examples/pendulum-method.rkt")]{pendulum planning example}
can be read into the same model. It returns and prints a timing plan; it does
not time a pendulum. The
@hyperlink[(source-file-url "examples/pendulum-period.md")]{young Galileo design case}
describes measurements and observed run checks that the current language
cannot yet record as run events. The
@hyperlink[(source-file-url "spec/representation.md")]{shared representation
contract} describes what readers in other languages should preserve; it does
not make the Racket assessor an implementation of those future applications.
