#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "interfaces"]{Records and interfaces}

An interface describes either the fields of a record or the named parts a
workflow must provide. These uses share a declaration word but have different
purposes. Fields and workflow parts cannot be mixed in one interface.
@secref["assessment"] explains the current structural checks on them.

@section{Declaration forms}

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "Purpose"))
   (list (tt "interface \"Name\" [field field = default ...]")
         "Declare a record shape and optional defaults")
   (list (tt "extends Parent")
         "Inherit fields from a local or imported record interface")
   (list (tt "interface \"Name\" [version \"...\" require part affects source target ...]")
         "Declare required workflow parts in a separate file")))

An @tt{interface} may have one nonempty @tt{version} line or omit it.
Record interfaces have fields and optional @tt{extends} lines. A bare field
must be supplied; @tt{field = value} gives a default. Workflow-part
interfaces have distinct @tt{require} lines and optional @tt{affects source
target} links between required parts. @tt{extends} does not apply to a
workflow-part interface.

@section{Record interfaces}

A record interface names fields. A bare name requires a supplied field; a
field with @tt{=} has a default. All fields must be present in the completed
record. Extra fields are allowed. There is no separate optional-field form.
The @hyperlink[(source-file-url "examples/record-interface.rkt")]{timing record example}
is a runnable workflow:

@verbatim|{
#lang sciencelogo

workflow "Check timing records"
interface "Timing" [duration unit = "seconds"]
trial = Timing.[duration = 2]
must trial implement Timing
revised = trial.[unit = "minutes"]
must revised implement Timing
must revised implement "interfaces/timing.rkt"
}|

@tt{Timing.[duration = 2]} creates a record with @tt{unit = "seconds"}.
Construction fails if any bare field remains absent. On the right side of an
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
Record fields and @tt{require} parts cannot be mixed in one interface.
@tt{implements ... [provide ...]} remains the form for workflow-part
interfaces.

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
  observation
  unit = "minutes"
]
interface "Timing" [duration unit = "seconds"]
interface "Location" [place]

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
also redeclare an inherited default as a bare required field. Identical field
declarations from different parents merge. If parents define the same field
differently, the child must declare that field explicitly to resolve the
conflict. Unknown parents and extension cycles are reader errors. Construction
checks all inherited required fields, and @tt{must} can check a resulting
record against the combined interface or any of its parents by field presence.
If every field has a default, @tt{Combined.[]} constructs a record
using those defaults.
An interface may also require or default a nested field, such as
@tt{clock.time} or @tt{clock.unit = "seconds"}. These are paths through a
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
Its @tt{require} lines name the parts to provide; @tt{affects source target}
marks a possible downstream effect if a required part is missing. A version
line can identify the interface, but the assessor does not compare versions.

The @hyperlink[(source-file-url "examples/meta-assessor/requirements/assessor.rkt")]{assessor interface}
is a separate @tt{#lang sciencelogo} file. It has one version and five required
parts:

@verbatim|{
#lang sciencelogo

interface "Assessor-process" [
  version "0.1"
  require parse
  require resolve-libraries
  require check-interfaces
  require trace-impacts
  require report

  affects parse check-interfaces
  affects resolve-libraries check-interfaces
  affects check-interfaces trace-impacts
  affects trace-impacts report
]
}|

The @hyperlink[(source-file-url "examples/meta-assessor/method.rkt")]{example workflow}
that supplies these parts is explained in @secref["assessment"]. These five
parts belong to the example interface; they are not built-in ScienceLogo parts.
