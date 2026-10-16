#lang scribble/manual
@(require "site-head.rkt")

@title[#:style (page-style) #:tag "getting-started"]{Getting started}

Install from a local checkout with @tt{raco pkg install --link .}. This first
example makes a plan for the young Galileo question: does a pendulum's period
change as its swing gets smaller? It describes work to do; it does not measure
a pendulum.

@section{Your first investigation}

Save this as @tt{investigation.rkt} and run @tt{racket investigation.rkt}:

@verbatim|{
#lang sciencelogo

workflow "Does the period change as the swing gets smaller?"
do timing-plan as plan
print plan

to timing-plan [
  output "Time ten swings as the swing gets smaller."
]
}|

@tt{to} defines a reusable procedure. @tt{do} calls it, @tt{output} returns
its text, and @tt{as plan} names that result. The caller prints the plan.
Definitions may appear after calls. This program prints a sentence; it neither
times swings nor records evidence.

@section{Calculate a period}

This second program shows how a procedure receives values and returns a number.
The example numbers illustrate the calculation; they are not recorded timings:

@verbatim|{
#lang sciencelogo

workflow "Calculate one example period"
do calculate-period 20 10 as seconds-per-swing
print seconds-per-swing

to calculate-period :elapsed :swings [
  output :elapsed / :swings
]
}|

@tt{:elapsed} and @tt{:swings} are inputs local to @tt{calculate-period}.
@tt{output} returns their quotient; @tt{as seconds-per-swing} names it for the
caller. A real investigation would identify the observations, units, and
conditions behind its values.
Read @secref["values"] and @secref["procedures"] for the exact rules. Then
@secref["stages"] shows how a written method declares what enters and leaves
a stage. Its paired stage form is checked by the reader but is not executed.
@secref["resources"] shows how the method names data outside the workflow and
records where values would be read or written. The language does not perform
those transfers.
