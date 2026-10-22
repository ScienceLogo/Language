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
   (list (tt "name = value")
         "Create or update a local named value")
   (list (tt "name += [field = value ...]")
         "Update or add fields on an existing record")
   (list (tt "name += number")
         "Add a number to an existing numeric value")
   (list (tt "name += value")
         "Append one item when name holds a list")
   (list (tt "output value")
         "Return a value from inside a procedure")
   (list (tt "print value")
         "Display a value on a line")))

@verbatim|{
do estimate-period 20 10 as period
print period

to estimate-period :seconds :swings [
  about "Estimate one period from a duration and swing count."
  output :seconds / :swings
]
}|

Inputs are declared with @tt{:} in the @tt{to} header and referenced with
@tt{:} inside that procedure, including in calls it makes. @tt{as period}
names the result in the caller. A call using @tt{as} needs an @tt{output} in
its procedure. Procedure names must be distinct; recursive calls are rejected.
@tt{print} is a teaching and display action, not a
scientific observation or evidence record.

An optional @tt{about "Markdown text"} belongs first inside a procedure's
opening bracket. It describes the reusable method and remains available
through imports and includes. It does not run as a command or replace its
input and result declarations. See @secref["descriptions"].

@section{Local values and scope}

@tt{name = value} creates a named value or updates a visible value
previously created by assignment. The procedure can read its declared inputs,
but does not see the caller's local names. A nested block can read names from
its parent and update a visible assigned name. A name first introduced inside
@tt{do [ ... ]}, a loop, or a branch remains inside that block; its parent and
sibling blocks cannot read it. There are no global variable declarations.

At command position, @tt{name = value} is assignment. A dotted target such as
@tt{trial.clock.time = "12:00"} updates nested content. Inside a record or
@tt{trial.[field = value]}, @tt{field = value} names a field; inside an
interface it supplies a field default. @tt{name += [field = value]} updates
or adds record fields; @tt{name.field += number} adds to an existing numeric
field. When the left side is a list, @tt{+=} appends one item. These updates
require an existing value on the left. In a condition such as
@tt{if count == 10 [ ... ]},
@tt{==} compares values. A comparison can be passed directly to a procedure,
as in @tt{do check count == 10}. Parentheses remain available to group an
expression.

@verbatim|{
attempts = 0
do [
  attempts += 1
  note = "inside this block"
]
print attempts
}|

Here @tt{attempts} becomes @tt{1}; @tt{note} is local to the @tt{do} block.
Procedure inputs, @tt{as} results, and @tt{for each} iteration names cannot
be changed by assignment. An @tt{as} result must introduce a new name in its
current scope. A @tt{to} procedure sees its own inputs, not values from the
surrounding workflow. Stages are labels, not variable scopes.

@section{Sequence and stage headers}

@tt{do [ commands ]} runs a block once, in order. @tt{stage name} labels
following commands until another stage at the same nesting level or the
block's end. A stage is a checkpoint for the written method; it is neither
a procedure nor a command to call. Stage names must be distinct across the
assembled workflow, including its procedures. A procedure defined between
stage headers remains available throughout its enclosing workflow.

@verbatim|{
workflow "Review a timing plan"
stage Prepare
do make-plan as plan
stage Review
print plan
to make-plan [output "Time ten swings as the swing gets smaller."]
}|

The second stage can use @tt{plan} because a stage does not create a new
scope. @tt{do Review} would call a procedure named @tt{Review}; it does not
call the stage. @secref["stages"] explains the paired form that declares a
stage's incoming and outgoing state.

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
updated by assignment. A @tt{repeat ... until} condition may read a name
introduced in its body. @tt{while} and @tt{repeat ... until} stop with an
error after 10,000 iterations if they have not terminated.

@verbatim|{
lengths = range 0.25 to 1 step 0.25
for each length in lengths [
  if length > 0.5 [print length]
]

done = false
repeat [
  done = true
] until done
}|
