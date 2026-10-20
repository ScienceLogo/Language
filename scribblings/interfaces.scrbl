#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "interfaces"]{Records and interfaces}

An interface describes the fields of a structured data object, called a
record, or the named parts a workflow may provide. Both use @tt{must [...]}
to identify required entries. A record check treats the entries as fields;
a workflow implementation declaration treats them as named workflow parts.
The reader accepts @tt{must [...]} in workflows, libraries, and separate
interface files. @secref["assessment"] explains the current structural checks.

@section{Required entries, defaults, and optional entries}

Present required entries together inside @tt{must [...]}, including entries
with defaults:

@verbatim|{
interface "Timing" [
  must [duration unit = "seconds"]
  notes
]
}|

@tt{duration} and @tt{unit} must both be present. When constructing a record,
supply @tt{duration}; the interface supplies @tt{"seconds"} for @tt{unit}
unless another value is provided. @tt{notes} may be absent.

@(tabular #:style 'boxed
  (list
   (list (bold "Entry") (bold "Meaning"))
   (list (tt "must [duration unit]") "Both fields are required; neither has a default")
   (list (tt "must [duration unit = \"seconds\"]")
         "Both fields are required; unit has an overridable default")
   (list (tt "notes") "Optional; may be absent")))

@tt{must} applies to every entry inside its brackets, whether they share a
line or use separate lines. A field with a default is compulsory even if it
is written outside @tt{must [...]}; grouping it inside makes that meaning
explicit and is the presentation used in this manual. Only an entry with
neither @tt{must} nor a default is optional. These rules are shared by data
interfaces and interfaces describing workflow parts. The
@hyperlink[(source-file-url "spec/interfaces.md")]{interface specification}
records the syntax and reader status.

@section{Declaration forms}

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "Purpose"))
   (list (tt "interface \"Name\" [must [required-field defaulted-field = value] optional-field]")
         "Declare required fields, their defaults, and optional fields")
   (list (tt "extends Parent")
         "Inherit fields from a local or imported record interface")
   (list (tt "interface \"Name\" [version \"...\" must [name ...] optional-name affects source target ...]")
         "Declare required and optional workflow parts in a separate file")))

An @tt{interface} may have one nonempty @tt{version} line or omit it.
Local and imported interfaces may have @tt{extends} lines. Interfaces
describing workflow parts use the same required-entry brackets and bare
optional names. An @tt{affects source target} line links two required entries.
Separate interface files cannot extend local interfaces.

@section{Nested protocol parts}

A name followed by brackets declares a part containing its own requirements.
The @hyperlink[(source-file-url "examples/interfaces/pendulum-protocol.rkt")]{pendulum protocol example}
uses the same @tt{must [...]} rule at each level:

@verbatim|{
interface "Pendulum-protocol" [
  version "1"
  must [
    measurement
    documentation [
      must [uncertainty]
      notes
    ]
  ]
  additional-measurements
]
}|

@tt{measurement} and @tt{documentation} are required. Within
@tt{documentation}, @tt{uncertainty} is required and @tt{notes} is optional.
@tt{additional-measurements} is optional at the protocol level. A default
on an entry makes that entry compulsory within its parent, as with other
interface entries.

Dots reference the hierarchy: @tt{Pendulum-protocol.documentation.uncertainty}
identifies the uncertainty part. Names are unique within their parent;
different parts can use the same child name. The interface version covers
the full hierarchy.

A declaration providing a parent also declares its required children.
For example, within an @tt{implements} declaration for this protocol:

@verbatim|{
provide documentation by "methods/documentation.rkt"
}|

This also claims @tt{documentation.uncertainty}. The child can instead be
referenced directly:

@verbatim|{
provide documentation.uncertainty by "methods/uncertainty.rkt"
}|

Providing one child does not claim its siblings. Optional nested parts
remain optional when their parent is provided. When an optional part is
provided, its own required children apply. These are declarations for
inspection; the structural check does not inspect the referenced work.

Named blocks also describe nested data fields. A nested part can be used
with the existing construction and record-check forms:

@verbatim|{
details = Pendulum-protocol.documentation.[uncertainty = unknown]
must details implement Pendulum-protocol.documentation
}|

The reader preserves the dotted names, each entry's requiredness, and parent
links for tools inspecting the protocol. @tt{version} and @tt{extends}
belong to the interface declaration; named parts contain entries and their
@tt{must [...]} groups. An @tt{affects} link inside a part uses names relative
to that part.

@section{Record interfaces}

A data interface names fields. Required fields, including those with
defaults, must be present in the completed record. Optional fields may be
absent, and extra fields are allowed. The
@hyperlink[(source-file-url "examples/record-interface.rkt")]{timing record example}
is a runnable workflow:

@verbatim|{
#lang sciencelogo

workflow "Check timing records"
interface "Timing" [must [duration unit = "seconds"]]
trial = Timing.[duration = 2]
must trial implement Timing
revised = trial.[unit = "minutes"]
must revised implement Timing
must revised implement "interfaces/timing.rkt"
}|

@tt{Timing.[duration = 2]} creates a record with @tt{unit = "seconds"}.
Construction fails if a required field remains absent after applying defaults.
On the right side of an
assignment, @tt{trial.[unit = "minutes"]} produces a modified value for
@tt{revised}; @tt{trial} retains its earlier value. The existing @tt{trial}
can also be updated:

@verbatim|{
trial += [unit = "minutes" note = "hand timed"]
trial.duration += 2
}|

After construction, @tt{+=} can replace @tt{unit}, add @tt{note}, or add to
the existing numeric @tt{duration}. Extra fields remain allowed.

A literal record can satisfy the same interface even when it was not
constructed from @tt{Timing}:

@verbatim|{
direct = [duration = unknown unit = "seconds"]
must direct implement Timing
}|

@tt{unknown} is an explicit field value and satisfies field presence. It does
not mean the field is absent or that its scientific value has been established.
The @tt{must} check is declarative: it examines the written record shape and
does not run the workflow. A direct record assignment or a dotted update has
a known shape. A record returned by a procedure, or one possibly changed by
a conditional or loop, is reported as undetermined. The check itself is
described in @secref["assessment"].

The same interface can be a separate
@hyperlink[(source-file-url "examples/interfaces/timing.rkt")]{@tt{#lang sciencelogo} file}.
In this example, @tt{must revised implement "interfaces/timing.rkt"} checks
against that file; the path
is relative to the workflow file. The assessor records the source revision
hash even when the optional @tt{version} is omitted. The standalone form
checks a record; local declarations supply a name usable in construction.
@tt{implements ... [provide ...]} remains the form for workflow-part
declarations; it checks the same compulsory and optional entries as a record
check, using provision declarations rather than record fields.

@section{Extend and combine record interfaces}

@tt{extends Parent} inherits a record interface. Repeating it combines
several parents. The
@hyperlink[(source-file-url "examples/combined-interface.rkt")]{combined interface example}
runs and passes the assessor:

@verbatim|{
workflow "Describe a pendulum trial"
interface "Timed-observation" [
  extends Timing
  extends Location
  must [observation unit = "minutes"]
]
interface "Timing" [must [duration unit = "seconds"]]
interface "Location" [must [place]]

trial = Timed-observation.[
  duration = 2
  place = "lab"
  observation = "ten swings"
]
must trial implement Timed-observation
must trial implement Timing
must trial implement Location
}|

The parent interfaces may be declared after the interface that extends them.
@tt{Timed-observation} requires @tt{duration}, @tt{place}, and @tt{observation};
its own @tt{unit = "minutes"} replaces the @tt{Timing} default. A child may
also replace an inherited default with a required field without a default,
written inside @tt{must [...]}. Identical field
declarations from different parents merge. If parents define the same field
differently, the child must declare that field explicitly to resolve the
conflict. Unknown parents and extension cycles are reader errors. Construction
checks all inherited required fields, and @tt{must} can check a resulting
record against the combined interface or any of its parents by field presence.
The same check follows nested groups. Unknown nested contents are reported
as undetermined; an optional group that is absent remains optional.
If every required field has a default, @tt{Combined.[]} constructs a record
using those defaults.
An interface may also declare required nested fields, including defaults,
as @tt{must [clock.time clock.unit = "seconds"]}. These are paths through a
record, with the same dot meaning used to read and update its values.
An inherited interface may be declared later in the same workflow, in an
included workflow file, or imported from a library. Importing a library as
@tt{timing} makes its @tt{Timing} record interface available as
@tt{timing.Timing}; write @tt{extends timing.Timing} in a local interface and
@tt{must trial implement timing.Timing} to check a record against it. A library
can itself extend an interface imported from another library. Its dependency
alias remains internal, so a workflow imports that dependency directly if it
needs to name the interface.

@section{Workflow-part interfaces}

A workflow-part interface lives in a separate @tt{#lang sciencelogo} file.
Its @tt{must [...]} group names parts that must be provided. Bare names
outside that group name parts that may be provided. An omitted optional part is not a
missing requirement. @tt{affects source target} marks a possible downstream effect
if a required part is missing. A version line can identify the interface,
but the assessor does not compare versions.

The @hyperlink[(source-file-url "examples/meta-assessor/requirements/assessor.rkt")]{assessor interface}
is a separate @tt{#lang sciencelogo} file. It has one version and five required
parts:

@verbatim|{
#lang sciencelogo

interface "Assessor-process" [
  version "0.1"
  must [
    parse
    resolve-libraries
    check-interfaces
    trace-impacts
    report
  ]

  affects parse check-interfaces
  affects resolve-libraries check-interfaces
  affects check-interfaces trace-impacts
  affects trace-impacts report
]
}|

The @hyperlink[(source-file-url "examples/meta-assessor/method.rkt")]{example workflow}
that supplies these parts is explained in @secref["assessment"]. These five
parts belong to the example interface; they are not built-in ScienceLogo parts.

For example, an interface can require measurement and allow supplementary
notes:

@verbatim|{
interface "Pendulum-recording" [
  version "1"
  must [measurement]
  supplementary-notes
]
}|

An @tt{implements} declaration may provide @tt{supplementary-notes}, but it
does not have to. The same required-entry rule applies when an interface
describes data fields: a bare name without a default is optional.
