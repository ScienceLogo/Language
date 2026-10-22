#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "stages"]{Stages and state}

A stage is a named section and checkpoint of a written method. The simple
@tt{stage name} header labels following commands; it creates no local
scope and does not itself perform work. A paired stage states what enters and
leaves it. The reader accepts and checks that declaration, but the reference
interpreter does not execute a paired stage's body. Neither form records an
observed run.

Both forms may have an optional @tt{about "Markdown text"} immediately after
their complete opening header. For a paired stage this means after its entry
state, as below. It describes the stage's purpose without adding an activity;
see @secref["descriptions"].

@verbatim|{
stage Inspect from state [information = [period = 2]]
about "Inspect the stated period."
end stage with state [information = [period = 2]]
}|

@section{The three sets}

A paired stage's state can contain three named sets. Each set is a record with
fields chosen for the investigation:

@(tabular #:style 'boxed
  (list
   (list (bold "Set") (bold "What it declares") (bold "Pendulum example"))
   (list (tt "information") "Material designated as available"
         "Question, observations, timing instructions")
   (list (tt "environment") "Relevant physical or digital setup"
         "Pendulum, timer, release setup")
   (list (tt "factors") "Possible influences considered when interpreting work"
         "Reaction time, changing swing angle")))

An information field says that material is designated as available; it does
not establish that a performer read it. An environment field describes a setup,
not proof that it existed in a particular run. A factor is @emph{considered};
its presence does not claim that it was controlled or negligible. The three
sets are available for human and AI activities. A hypothesis can be a named
field within @tt{information}; it is not a compulsory fourth set. The
@secref["propositions"] page shows how a named proposition can be carried in
@tt{information} across stages. The
@hyperlink[(source-file-url "spec/context.md")]{context set definitions} explain
why these distinctions matter.

@section{Declare entry and exit}

@tt{stage name from state [ ... ]} opens a paired stage, optionally with
@tt{by performer-name} before @tt{from}, and
@tt{end stage with state [ ... ]} closes it. Both state objects are required,
even when empty: @tt{state []}. A set may be absent, present and empty, or
present with fields. Those are distinct from a field whose value is
@tt{unknown}: that field exists, but its value is not stated. The exit object
declares the complete state after the stage, including fields retained from
entry.

@section{Identify the performer}

A @tt{performer name [field = value ...]} declaration names who or what is
designated to carry out an activity. It belongs directly in a workflow.
Its fields are open: @tt{performer researcher []} is valid, and a workflow
can add fields such as @tt{kind} or @tt{role} when useful. The name is a
reference to this object, not a quoted label.
Its fields use ordinary dotted access, such as @tt{researcher.role}.

A paired stage may give its calls a default performer with @tt{by name}.
A call may use @tt{by another-name} to override that default. Every call
that writes to state with @tt{into} must resolve to a declared performer;
when a stage has no default, each call must name one. This identifies the
designated performer in the written method, not who actually carried out
a particular run. @tt{end stage} needs no performer.

@verbatim|{
#lang sciencelogo
workflow "Does the period change as the swing gets smaller?"

to calculate-period :duration :count [
  output :duration / :count
]

performer researcher [kind = "human" role = "scientist"]

stage Analyze by researcher from state [
  information = [elapsed = unknown swing-count = 10]
  environment = [timer = "hand timer"]
  factors = [reaction-time = unknown]
]
do calculate-period with [
  duration at information.elapsed
  count at information.swing-count
] into information.period
end stage with state [
  information = [elapsed = unknown swing-count = 10 period = unknown]
  environment = [timer = "hand timer"]
  factors = [reaction-time = unknown]
]
}|

This is a @emph{method declaration}. It says where a duration and a swing
count would come from and where the calculated period would go. It does not
measure the duration or calculate an observed period. The example keeps the
timer and considered factor at exit because neither was changed by a call.
The state declaration may also spell nested entries as paths, for example
@tt{information.clock.time = "12:00"}.

@section{Connect a procedure to state}

Inside a paired stage, a procedure call maps each declared input to a field
location in the current state:

@verbatim|{
do calculate-period with [
  duration at information.elapsed
  count at information.swing-count
] into information.period
}|

@tt{duration} and @tt{count} match the procedure's input names without the
definition-only colon. A location starts with @tt{information},
@tt{environment}, or @tt{factors}; dots select nested fields. The @tt{into}
location receives the procedure's return and may name a new field under an
existing parent record. Every paired-stage call needs @tt{into}. If a
procedure has no inputs, write @tt{do name into information.result}; otherwise
@tt{with [ ... ]} supplies every input exactly once. An imported procedure
uses its qualified name, such as @tt{timing.calculate-period}.

Calls in a paired stage take scientific inputs from state locations. They do
not take a literal or an unrelated local name as an argument. A local
assigned name may be used only for an integer counter or position; inside
this form, @tt{for each} likewise needs integer positions. Only a declared
@tt{into} location, or fields within a record returned to it, can change
through a call. The same location can be both an input and an output.
The reserved list property @tt{information.measurements.count} can be read
as an input location or used for an integer counter or range bound. It is
computed from the list, so it is not another stored state field and cannot
be an @tt{into} location or the target of a resource read.
An assignment from a declared @secref["resources"] can also change a state
field; an assignment to a resource path declares an outbound transfer.

@section{Reader checks for paired stages}

The reader rejects a paired stage when:

@itemlist[
 @item{Either state boundary is missing, a set has the wrong shape, or a
       location names a set or field that is unavailable when read.}
 @item{A call's input names are missing, extra, or repeated, or its procedure
       can finish normally without @tt{output}.}
 @item{A return has no existing parent location in state.}
 @item{A @tt{by} name has no performer declaration, or a state-changing call
       has neither its own performer nor a stage default.}
 @item{The closing state omits an available field, adds a field without a
       guaranteed return or resource read, or changes an entry value without a return or resource read that
       targets that field or its containing record.}
]

A field returned only on some branches is not guaranteed to exist at exit.
These checks establish the declared flow of values, not whether the work took
place or whether its scientific conclusion is sound. A one-based position
inside a list can be named, such as @tt{information.trials.[2]} or
@tt{information.trials.[position]}. A named position must be a stage control
name. The containing list and selected positions must appear in the declared
state.
The @hyperlink[(source-file-url "spec/stage-state.md")]{stage state contract}
records the accepted reader constraints.
@secref["resources"] shows how a paired stage can declare reads from and
writes to data storage outside the workflow.
@secref["assessment"] explains the distinct structural checks available
through @tt{must} and workflow interfaces.
