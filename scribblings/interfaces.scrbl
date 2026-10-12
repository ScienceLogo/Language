#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "interfaces"]{Structural assessment}

An interface can state which named parts a particular method must provide and how
an omission may affect later parts. This is a structural check, not a judgment of
scientific adequacy.

The @hyperlink[(source-file-url "examples/meta-assessor/requirements/assessor.rkt")]{assessor interface}
is a separate @tt{#lang sciencelogo} file. It has one version and five required
parts:

@verbatim|{
#lang sciencelogo

interface "ScienceLogo assessor" [
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

The @hyperlink[(source-file-url "examples/meta-assessor/method.rkt")]{complete investigation}
references that file and supplies an implementation reference for each part:

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

Run this from an installed checkout:

@verbatim|{
racket -l sciencelogo/assessor -- examples/meta-assessor/method.rkt
racket -l sciencelogo/assessor -- examples/meta-assessor/missing-impact.rkt
}|

The first command reports no structural issues. The second uses an incomplete
investigation: it reports missing @tt{trace-impacts} and marks @tt{report} as
affected through the declared @tt{affects} link. It exits with status 1.

The interface path is relative to the investigation file. A @tt{provide} reference
is a claim, not proof that the named work exists or is correct; the assessor does
not inspect those references. The five names belong to this interface. ScienceLogo
does not require every workflow activity or item to have an author-written name.
An interface may omit @tt{version}. The report identifies its source revision
with a hash; the assessor does not compare versions.

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
set trial to Timing but [duration = 2]
must trial implement Timing
set revised to trial but [unit = "minutes"]
must revised implement Timing
must revised implement "interfaces/timing.rkt"
}|

@tt{Timing but [duration = 2]} creates a record with @tt{unit = "seconds"}.
Construction fails if any bare field remains absent. @tt{but} on an existing
record makes a copy with the listed fields changed; it leaves the original
record unchanged. A literal record can satisfy the same interface even when
it was not constructed from @tt{Timing}:

@verbatim|{
set direct to [duration = unknown unit = "seconds"]
must direct implement Timing
}|

@tt{unknown} is an explicit field value and satisfies field presence. It does
not mean the field is absent or that its scientific value has been established.
The @tt{must} check is declarative: it examines the written record shape and
does not run the workflow. A direct @tt{set} to a record or a @tt{but} copy has
a known shape. A record returned by a procedure, or one possibly changed by
a conditional or loop, is reported as undetermined.

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

@section{Require a call in the written method}

The @tt{must do} form belongs directly in an investigation:

@verbatim|{
#lang sciencelogo

workflow "How will we compare pendulum periods?"
must do compare-periods
do prepare-comparison
to prepare-comparison [do compare-periods]
to compare-periods []
}|

The assessor reports this condition as satisfied because the investigation calls
@tt{prepare-comparison}, which calls @tt{compare-periods} on the written method's
required path. A definition alone, a call inside an unused procedure, or a call
only under @tt{if false} or @tt{repeat 0} does not satisfy it. A call that depends
on an unresolved condition is reported as undetermined. This check resolves
literal conditions and counts; named values and procedure inputs remain unknown.
The declaration does not run the procedure or establish that the work happened
or was scientifically adequate.

@section{Inspect the method model}

The implemented @hyperlink[(source-file-url "workflow-model.rkt")]{workflow model}
records the written investigation as procedures, activities, named input and result
slots, imports, interface claims, @tt{must do} conditions, and typed relations.
@tt{read-workflow-model} reads
an investigation file; @tt{read-interface-model} reads an interface file. Method
elements carry source locations. A call links to its procedure with @tt{invokes}; named
results link to their producing and using activities. A sequence retains command order.
The model describes the method and does not say that a scientific activity occurred.
The assessor also checks that each activity and named item has one containment link to
its recorded parent.

@tt{assess-workflow} checks this model; @tt{assess-file} reads the file first. The
returned assessment includes condition checks and findings that identify their
targets. For a @tt{require} part, @tt{satisfied} means a matching @tt{provide}
declaration exists. A missing part is @tt{violated}. A downstream part reached through
@tt{affects} is reported as possibly affected, with an @tt{undetermined} outcome for
that impact. This assessment does not verify the content of a provision or a run.

The @hyperlink[(source-file-url "examples/pendulum-method.rkt")]{pendulum planning example}
can be read into the same model. It returns and prints a timing plan; it does not time
a pendulum. The @hyperlink[(source-file-url "examples/pendulum-period.md")]{young Galileo design case}
describes measurements and run checks that the current language cannot yet express.
