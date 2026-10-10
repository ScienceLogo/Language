#lang scribble/manual

@title[#:style '(toc) #:tag "getting-started"]{Getting started}

Install from a local checkout with @tt{raco pkg install --link .}. The two programs
below are in the repository's @tt{examples} directory.

@section{Your first investigation}

Run @tt{racket examples/first-slice.rkt}:

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

It prints the two reminders in the order requested by @tt{do}. Procedure
definitions may appear after their calls. These @tt{print} commands display text;
they do not measure a plant or record evidence.

@section{Return a plan}

Run @tt{racket examples/return-a-plan.rkt}:

@verbatim|{
#lang sciencelogo

investigate "What is our observation plan?" [
  do observation-plan as plan
  print plan

  to observation-plan [output "Measure plant height each day."]
]
}|

@tt{output} returns the plan text, and @tt{as plan} gives it a name in the
investigation. Only the caller prints it. The procedure does not itself carry
out the plan or record scientific evidence.
