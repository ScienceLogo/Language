#lang scribble/manual
@(require racket/runtime-path)
@(define-runtime-path logo-path "../assets/logo.png")

@title{ScienceLogo}
@author{Riccardo Boero}

@image[logo-path #:scale 0.12]{ScienceLogo logo}

@bold{Humans first in AI science.}

@hyperlink["https://github.com/open-and-sustainable/ScienceLogo"]{Source code and issues}
@" · "
@hyperlink["https://github.com/open-and-sustainable/ScienceLogo/tree/main/spec"]{Language specifications}
@" · "
@hyperlink["https://github.com/open-and-sustainable/ScienceLogo/blob/main/CITATION.cff"]{How to cite ScienceLogo}

ScienceLogo is a Logo dialect for scientific workflows. It aims to make scientific
methods readable while giving people ways to inspect and supervise work performed
with AI. The language is under development: the current runnable subset is a small
teaching slice, and the broader scientific and AI constructs are still being designed.

@section{Run your first investigation}

Install the package from a local checkout with @tt{raco pkg install --link .}, then
run @tt{racket examples/first-slice.rkt}. The example is:

@verbatim|{
#lang sciencelogo

investigate "How will we study plant growth?" [
  do [
    do introduce
    do finish
  ]

  to finish [
    print "Keep each observation with its date."
  ]

  to introduce [
    print "Measure plant height each day."
  ]
]
}|

It prints two lines in the order requested by the @tt{do} block. The procedure
definitions can appear after their calls.

@section{Pass a value and get a result}

A procedure can receive an item and give a result back:

@verbatim|{
#lang sciencelogo

investigate "What should we measure?" [
  do observation-plan "Bean plant" as plan
  print plan

  to observation-plan :plant [
    print :plant
    output "Measure its height each day."
  ]
]
}|

The call supplies @tt{"Bean plant"}. Inside the procedure, @tt{:plant} names that input.
@tt{output} gives a value back, and @tt{as plan} names it in the investigation. This
program prints @tt{Bean plant}, then @tt{Measure its height each day.} Run it from a
local checkout with @tt{racket examples/inputs-and-results.rkt}.

@section{Commands available today}

@itemlist[
  @item{@tt{investigate "question" [ ... ]} starts the one investigation in a file.}
  @item{@tt{to name :input ... [ ... ]} defines a procedure with optional inputs.
        It does not run until called. Definitions belong directly inside the investigation.}
  @item{@tt{do name value ... as result} calls a procedure, optionally supplying values
        and naming its returned result.}
  @item{@tt{do [ ... ]} runs its commands once, in order.}
  @item{@tt{output value} returns a value from a procedure.}
  @item{@tt{print value} displays a line of text. It does not record a scientific
        observation or evidence.}
]

For now, a value can be quoted text, a declared @tt{:input} inside its procedure,
or a result named earlier with @tt{as}. A nested @tt{do [ ... ]} block can read
results from its enclosing blocks. Results named inside the nested block stay there;
enclosing and sibling blocks cannot read them. A result name cannot duplicate an input
or another result visible in its block. Separate sibling blocks may use the same name.
A procedure sees only its declared inputs, not the caller's result names. The colon is
only used for procedure inputs.

Use @tt{;} for a line comment. A block comment begins with @tt{#|} and ends with
@tt{|#}; block comments can nest. Whitespace is flexible, and empty blocks are
allowed.

The reader checks the whole investigation before it runs. It rejects unknown or
duplicate procedure names, wrong input counts, unknown input or result names, calls
that request a result from a procedure without @tt{output}, malformed brackets,
unsupported commands, and recursive procedure calls. Procedure names are local to
the investigation.

@section{What is still being designed}

Scientific items, measurements, repetition, stages, standards, declarative obligations,
agents, and evidence are not implemented in this first slice. The
@hyperlink["https://github.com/open-and-sustainable/ScienceLogo"]{source repository}
contains further examples. Those examples explore
how human review, traceability, and control of AI work might become part of a
scientific method; they are not yet executable ScienceLogo programs.
