#lang scribble/manual
@(require "site-head.rkt")

@title[#:style (page-style) #:tag "getting-started"]{Getting started}

Install from a local checkout with @tt{raco pkg install --link .}. The two programs
below are in the repository's @tt{examples} directory.

@section{Your first investigation}

Run @tt{racket examples/first-slice.rkt}:

@verbatim|{
#lang sciencelogo

workflow "How will we study a pendulum?"
do [
  do introduce
  do finish
]

to finish [
  print "Keep each timing with its length and unit."
]

to introduce [
  print "Time ten swings at each length."
]
}|

It prints the two reminders in the order requested by @tt{do}. Procedure
definitions may appear after their calls. These @tt{print} commands display text;
they do not time a pendulum or record evidence.

@section{Return a plan}

Run @tt{racket examples/return-a-plan.rkt}:

@verbatim|{
#lang sciencelogo

workflow "What is our observation plan?"
do observation-plan as plan
print plan

to observation-plan [output "Time ten swings at each length."]
}|

@tt{output} returns the plan text, and @tt{as plan} gives it a name in the
investigation. Only the caller prints it. The procedure does not itself carry
out the plan or record scientific evidence.
