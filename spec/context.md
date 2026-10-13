# Stage state and context sets (draft)

**Status:** the reader accepts the stage and call forms below and checks their
declared structure. The interpreter does not carry out calls inside a state
stage or create an observed run. List-element locations and the syntax for
other state updates remain to be specified. This page does not define how an
assessment application analyzes the sets.

## What context covers

Context is the information and circumstances relevant to a particular piece of
scientific work. A workflow should state the context it considers relevant; it
cannot list everything in the world that might matter. Different activities in
the same workflow may have different contexts. A source available to a scientist
is not automatically available to an AI agent.

ScienceLogo distinguishes three named sets within a stage's state:

| Set | Question it answers | Examples |
| --- | --- | --- |
| **Information set** | What information, instructions, or source material is designated as available to this activity or actor? | Research criteria, data, a paper's abstract, a prompt, a supplied passage, or the contents of retained memory. |
| **Environment set** | Under what relevant physical or digital conditions is the activity specified to take place? | A stopwatch and pendulum setup, instrument settings, software or model version, available tools, or a retrieval setup. |
| **Factors set** | Which possible influences has the scientist considered when interpreting an activity or result? | Human reaction time in hand timing, release angle, text order or truncation in an LLM request, or a model change between attempts. |

An information set names material made available at a particular point. It does
not claim that the actor read or used every member. An environment set names the
relevant setup; it does not claim that an intended setting was in effect during an
observed run. The written method and a record of what actually happened remain
distinct.

Hypotheses can be kept as a named collection within the information set. Each
claim can retain its identity, status, and links to the observations used to
assess it. A later claim can refer to an earlier one without erasing it. This
does not make hypotheses a fourth set required by every workflow.

The factors set is a set of **considered** influences, not a list of factors the
scientist has necessarily controlled. A factor can refer to something already
named in the information or environment set. For example, release angle can be
part of the pendulum environment and also a considered factor for the measured
period. When useful, the workflow can say which activity or result a factor may
affect and how the method handles it. Merely naming a factor does not establish
that its influence is negligible or that a control worked. **Controls** are the
factors for which the method states a means of control or accounting; the word
does not name the entire third set.

Whether something is a nuisance factor depends on the research question. Model
version may be a possible unwanted influence in a paper-screening study and the
main subject of a study comparing models. The language must not impose a fixed
catalogue of nuisance factors on all workflows. An undeclared factor cannot be
treated as negligible merely because it is absent; whether an expected factor is
missing is a separate scientific question.

## Two examples

For a pendulum timing activity, the information set might name the question,
the initial hypothesis about shrinking swings, timing instructions, and the
definition of a full swing. The environment set might name the pendulum,
stopwatch, and release setup. The factors set might identify human reaction
time and changes in swing angle during timing as possible influences on the
recorded period. The method can describe how it handles each without asserting
that the timing has already happened. The [young Galileo example](../examples/pendulum-period.md)
follows the hypothesis, observations, and revised explanation across stages.

For an AI-assisted paper-screening activity, the agent's information set might
contain the inclusion criterion, title, abstract, and prompt. The full text may
belong to a human reviewer's information set without belonging to the agent's.
The agent's environment set might name the model version, settings, available
tools, and memory setup. The factors set might identify text order, truncated
context, or earlier conversation as possible influences on a suggestion. These
are considered relative to that screening activity; another investigation may
give them different roles.

## What the language needs to preserve

The three labels distinguish named collections of ordinary values, records, and
references; they do not impose fixed scientific fields. Each set needs an
unambiguous identity and scope. Its members must be referable without copying
their descriptions into every activity. A set's location or an explicit
reference shows which activity it describes. Additional links, such as a factor
to a particular result, can be stated when the workflow needs them. These are
descriptions of the **specified method**. A later record of a particular run
may state what information was actually supplied and what environment was
actually in effect, without turning the method's declarations into claims that
those events occurred.

## Stage entry and exit

`stage "name" from state [ ... ]` begins a stage. It needs no additional
`start` command. `end stage with state [ ... ]` closes it. The opening object
defines what enters the stage; the closing object states everything that leaves
it. Both objects are compulsory, even when empty (`state []`). The three sets
may be present as needed. An absent set, an explicitly empty set, and a set
containing `unknown` have different meanings. Values in the closing state
must be traceable to the incoming state or to explicit work inside the stage;
writing a new value at the boundary alone does not imply that work occurred.
The stage remains a section and checkpoint, not a callable procedure.

The earlier runnable form, `stage "name"`, remains a header ending at the
next header or enclosing block. A paired state stage is read and checked but
its body is not executed by the current interpreter.

## Calling a function from a stage

Within a stage, state is the complete interface for values. A call supplies
the names and locations of its inputs, then names the location that receives
its return. For example:

```text
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
```

This syntax is accepted by the reader but is not executed. `duration` and `count` are
the function's declared inputs without their definition-only colons. The
names after `at` are paths inside the stage state. `information.elapsed`
means the `elapsed` field of the `information` set; the dot separates fields
in a state location. The call declares that the function reads the values at
those locations and directs its return to `information.period`, which may be
a new field. Here `unknown`
declares a present value whose actual value is not stated by this method. An
observed run would provide its own values and evidence.

The `with [ ... ]` part is required when the function declares inputs. A
function with no inputs can be called as `do name into information.result`.
Every stage call needs `into`, and every function called this way needs an
`output` on every path that can finish normally. A function with no scientific
result may return a Boolean completion status to a named location; a status
written in a method is not evidence that a run occurred. An imported function
uses the same call form, for example `do timing.calculate-period with [ ... ]
into information.period`. The dot in a procedure name qualifies its library;
the dot after `at` or `into` separates fields in a state location.

Inputs are read from their stated locations. Only an explicit `into` location
can change through a call, including when that location is also an input.
A function can return a record when several related results belong together.
Internal variables may serve as counters or positions within state collections.
Any such value passed to a function as a scientific input must itself have a
location in the state. A literal intended as a stage-call argument must first
be placed in state rather than passed directly. The reader permits local
`set` values in a state stage only when it can establish an integer counter or
position expression; `for each` there likewise needs integer positions.

## Checking stage calls

The reader checks the written method before accepting a stage call:

- The procedure exists, including when named through a library alias. Each
  declared input has exactly one mapping; duplicate, missing, or extra input
  names are errors. Mapping order does not matter.
- Each `at` path begins with a set present in the current state, and every
  field on the path exists when the call is reached. An explicitly present
  `unknown` value is not a missing field. A path produced only on some earlier
  branches cannot be treated as certainly present.
- The `into` path begins with a present set. Its parent fields exist. Its final
  field may be new or existing. An existing field may receive an updated value;
  a new field must appear in the closing state. Other fields cannot silently
  disappear between the opening and closing states.
- The called procedure returns a value on every path that can finish normally.
  If this cannot be established, the call is rejected.
- Fields already in the opening state retain their stated values at exit unless
  an explicit return targets them or a containing record. A conditional return
  alone cannot establish that a new field is present on every path.

These checks establish names, locations, and declared flow. They do not verify
that the procedure ran, that the returned value has a scientifically suitable
meaning, or that the stated environment existed in an observed run. An
interface could add a check on a value's shape without making all ScienceLogo
values strongly typed. The notation for a position inside a list-valued
location remains open; the whole list can already be named as a location.
