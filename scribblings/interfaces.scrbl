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
Interface versions appear in the report, but this assessor does not compare them.

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
@tt{prepare-comparison}, which calls @tt{compare-periods}. A definition alone, or a
call inside an unused procedure, does not satisfy it. The declaration does not run
the procedure. It checks the method's call structure, not whether the work happened
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
