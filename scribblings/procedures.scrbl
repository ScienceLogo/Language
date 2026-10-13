#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "procedures"]{Procedures and control flow}

A workflow contains commands and named procedures. Commands run in written
order; a @tt{to} declaration makes a procedure available but does not run it.
Definitions may appear after calls. The @secref["reference"] page gives the
naming convention and file-level rules.

@section{Procedures, calls, and results}

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "Meaning"))
   (list (tt "to name :input ... [ commands ]")
         "Define a procedure with zero or more inputs")
   (list (tt "do name value ...")
         "Call a procedure for its actions")
   (list (tt "do name value ... as result")
         "Call a procedure and name its returned value")
   (list (tt "output value")
         "Return a value from inside a procedure")
   (list (tt "print value")
         "Display a value on a line")))

@verbatim|{
do estimate-period 20 10 as period
print period

to estimate-period :seconds :swings [
  output :seconds / :swings
]
}|

Inputs are declared with @tt{:} in the @tt{to} header and referenced with
@tt{:} inside that procedure, including in calls it makes. @tt{as period}
names the result in the caller. A call using @tt{as} needs an @tt{output} in
its procedure. Procedure names must be distinct; recursion is not supported
by the current reader. @tt{print} is a teaching and display action, not a
scientific observation or evidence record.

@section{Local values and scope}

@tt{set name to value} creates a named value or updates a visible value
previously created with @tt{set}. The procedure can read its declared inputs,
but does not see the caller's local names. A nested block can read names from
its parent and update a visible @tt{set} name. A name first introduced inside
@tt{do [ ... ]}, a loop, or a branch remains inside that block; its parent and
sibling blocks cannot read it. There are no global variable declarations.

@verbatim|{
set attempts to 0
do [
  set attempts to attempts + 1
  set note to "inside this block"
]
print attempts
}|

Here @tt{attempts} becomes @tt{1}; @tt{note} is local to the @tt{do} block.
Procedure inputs, @tt{as} results, and @tt{for each} iteration names cannot
be changed with @tt{set}. An @tt{as} result must introduce a new name in its
current scope. A @tt{to} procedure sees its own inputs, not values from the
surrounding workflow. Stages are labels, not variable scopes.

@section{Sequence and stages}

@tt{do [ commands ]} runs a block once, in order. @tt{stage "title"} labels
following commands until another stage at the same nesting level or the
block's end. A stage is a checkpoint for the written method; it is neither
a procedure nor a command to call. Stage names must be distinct across the
assembled workflow, including its procedures. A procedure defined between
stage headers remains available throughout its enclosing workflow.

@verbatim|{
workflow "Review a timing plan"
stage "Prepare"
do make-plan as plan
stage "Review"
print plan
to make-plan [output "Time ten swings at each length."]
}|

The second stage can use @tt{plan} because a stage does not create a new
scope. @tt{do Review} would call a procedure named @tt{Review}; it does not
call the stage.

@subsection{Stages with declared state}

The reader also accepts @tt{stage "title" from state [ ... ]} paired with
@tt{end stage with state [ ... ]}. Both state objects are required, even when
empty. They can contain @tt{information}, @tt{environment}, and @tt{factors}
sets. This form describes inputs, return locations, and what leaves the stage.
It is checked as a written method; the current interpreter does not execute
the body of a state stage or perform a measurement.

@verbatim|{
to calculate-period :duration :count [output :duration / :count]

stage "Analyze" from state [
  information = [elapsed = unknown swing-count = 10]
]
do calculate-period with [
  duration at information.elapsed
  count at information.swing-count
] into information.period
end stage with state [
  information = [elapsed = unknown swing-count = 10 period = unknown]
]
}|

The name before @tt{at} matches a procedure input. The dotted name after
@tt{at} is its location in state; @tt{into} names the required return
location. The reader rejects missing or extra input mappings, unavailable
paths, a return with no valid destination, a procedure that may finish without
@tt{output}, and changes at exit without an explicit return. Local @tt{set}
values inside a state stage are limited to integer counters or positions.
See the @hyperlink[(source-file-url "spec/context.md")]{stage state specification}
for the complete reader checks and current limits.

@section{Conditions and repetition}

Each condition is a Boolean expression or comparison from @secref["values"].
An unknown or nonboolean condition stops execution instead of choosing a
branch. Square brackets delimit each command block.

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "Meaning"))
   (list (tt "if condition [ ... ] else if condition [ ... ] else [ ... ]")
         "Run the first true branch; the final else is optional")
   (list (tt "repeat count [ ... ]")
         "Run a block a fixed number of times")
   (list (tt "for each name in sequence [ ... ]")
         "Run once per item in an ordered list")
   (list (tt "while condition [ ... ]")
         "Test before each iteration")
   (list (tt "repeat [ ... ] until condition")
         "Run once, then test after each iteration")))

@tt{repeat} needs a nonnegative integer count. @tt{for each} needs an ordered
list; its iteration name exists only inside that iteration and cannot be
updated with @tt{set}. A @tt{repeat ... until} condition may read a name
introduced in its body. @tt{while} and @tt{repeat ... until} stop with an
error after 10,000 iterations if they have not terminated.

@verbatim|{
set lengths to range 0.25 to 1 step 0.25
for each length in lengths [
  if length > 0.5 [print length]
]

set done to false
repeat [
  set done to true
] until done
}|
