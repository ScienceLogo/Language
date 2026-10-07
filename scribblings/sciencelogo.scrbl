#lang scribble/manual

@title{ScienceLogo}
@author{Riccardo Boero}

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

@section{Commands available today}

@itemlist[
  @item{@tt{investigate "question" [ ... ]} starts the one investigation in a file.}
  @item{@tt{to name [ ... ]} defines a procedure without running it. Definitions
        belong directly inside the investigation.}
  @item{@tt{do name} calls a procedure.}
  @item{@tt{do [ ... ]} runs its commands once, in order.}
  @item{@tt{print "text"} displays a line of text. It does not record a scientific
        observation or evidence.}
]

Use @tt{;} for a line comment. A block comment begins with @tt{#|} and ends with
@tt{|#}; block comments can nest. Whitespace is flexible, and empty blocks are
allowed.

The reader checks the whole investigation before it runs. It rejects unknown or
duplicate procedure names, malformed brackets, unsupported commands, and recursive
procedure calls. Procedure names are local to the investigation.

@section{What is still being designed}

Inputs and results, repetition, stages, standards, declarative obligations, agents,
and scientific evidence are not implemented in this first slice. The
@hyperlink["https://github.com/open-and-sustainable/ScienceLogo"]{source repository}
contains further examples. Those examples explore
how human review, traceability, and control of AI work might become part of a
scientific method; they are not yet executable ScienceLogo programs.
