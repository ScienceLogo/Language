# Prompts and obligations (draft)

**Status:** design proposal beyond the [first runnable subset](first-slice.md). This
develops the [semantic core](core.md) using the
[knowledge-synthesis example](../examples/knowledge-synthesis.md).

## Which words declare, and which words act?

`must` is the proposed **obligation declaration**. It says what a workflow or run is required
to do or preserve. It does not perform an action when execution reaches that line. For
example, `must send every unsure screening decision to a human` requires a check; `ask human`
is the action that may satisfy it. A procedure can take another path, fail, or be interrupted,
so writing the `ask` action alone cannot establish that the obligation held in a run.

`must` is not the only declarative word. `criteria`, `fields`, `prompt`, `settings`, and
`agent` name parts of the method. Their names can be referenced by procedures. `to` names a
procedure; its commands, including `ask`, `if`, and `for each`, specify possible actions and
order. Nesting scopes names and rules to the investigation or procedure that contains them.
An obligation inside a procedure applies to each call of that procedure; one in an
investigation applies across its relevant activities.

In the first syntax sketch, `to name [ ... ]` defines a reusable procedure without running
it. `do name` calls it once at that point; `do [ ... ]` runs a block of commands once, in
order. Named declarations in an investigation or library are resolved before a method
runs: a procedure may be called before its `to` definition appears in the source. The
validator checks that the name resolves in the containing scope or an imported library
and reports missing or ambiguous names before execution. This does not let a step read
an `as` result that has not yet been produced.

The implemented `stage "name"` form is a header for the following executable commands, up to the next stage
header at the same bracket depth or the end of that enclosing block. It labels a section
for documentation and references without defining or calling a procedure, changing name
visibility, or adding a check. Its end can be a checkpoint for a separately declared
condition. A `to` definition between stage headers remains a definition in the enclosing
scope; its position there does not execute it or make it part of that stage's run. In this
slice, `do` calls a reusable `to` procedure, not a stage header; whether a stage ever
needs a separate call form remains open. The same stage may be reached in several loop
iterations or procedure calls, with each occurrence distinguished in a run trace.
Stage declarations have distinct names across a workflow and its local procedures;
imported library stages carry their alias. Procedure definitions also have distinct
names, with imported procedures qualified by their alias.
`repeat count [ ... ]`, `for each name in sequence [ ... ]`,
`while condition [ ... ]`, and `repeat [ ... ] until condition` are the
implemented looping forms. A procedure may measure,
record, or ask someone to act, so it need not be a pure function returning a value.
Whether `do` must prefix every top-level activity is still open; the
[pendulum method](../examples/pendulum-method.rkt) shows the explicit form.
The exact syntax for linking a stage to a research protocol remains open.

For example, this source order is valid in the proposed model, even though the definition
is written after its first call:

```text
workflow "How does length affect a pendulum's period?"
do make-timing-plan
to make-timing-plan [
  print "Time ten swings at each length."
]
```

Definitions can appear before or after their calls. A publication may choose another
reading order; runtime order still comes from the executable calls, branches, and loops
in the method. An unordered set of declarations does not imply unordered execution.

### Activities with no required order

The language also needs a way to say that several activities are required but may occur
in any order. A candidate form is:

```text
stage "Prepare"
any order [
  do measure-length as length
  do calibrate-timer as calibration
]
stage "Time"
do time-swings length calibration as timing
```

`any order` would run both calls once. The group would expose their `as` results to the
enclosing block only after both complete; neither call may use the other's result
inside the group. A runtime may execute them one after another or concurrently; the
method does not require either choice. The run records each call's start, completion,
result, and any failure; overlapping calls need not be given a fictional order.
`Time` cannot start until both results are available. A failed child cannot silently
count as completed; recovery and shared-state rules still need design.
A checker should accept either sequential order or overlap and reject a run that starts
`Time` before both finish. General dependencies beyond this shared completion point
may need a different form. This is a semantic test and candidate spelling, not adopted
syntax.

### Names, inputs, and results

Logo [uses `:name`](https://people.eecs.berkeley.edu/~bh/docs/html/usermanual_7.html)
for the value of a named input or variable. ScienceLogo would use `:` more narrowly: only
for procedure inputs. The header `to time-pendulum :pendulum [ ... ]` declares a local input
named `pendulum`. Within that procedure, `:pendulum` reads the caller's item. The procedure
can pass that item to another procedure in a call. For example, a procedure with inputs
`:setup` and `:length` may call `do time-pendulum :setup :length as timing`. A caller outside
the procedure names its own input or investigation item; the callee's `:pendulum` is not visible
there. The colon is not a pointer or an instruction to change an item.

`as elapsed-time` names a step's result in the current block; later steps there or in
nested blocks refer to `elapsed-time` without a colon. `output timing` returns the
named item to the caller. The call
`do time-pendulum P1 "0.50 m" as first-timing` gives that value a local name in the
caller. `first-timing` is then used without a colon. A result name does not change the
item's scientific status or provenance.

The proposed `any order` group would explicitly export its child result names to the
enclosing block after completion; the exact scoping rule is part of that candidate.

This remains a syntax sketch, not a runnable program:

```text
to time-pendulum :pendulum :length [
  require :pendulum is a pendulum
  require :length has a unit
  must result has pendulum, length, swing count, duration, and time unit
  time ten swings of :pendulum at :length as elapsed-time
  record elapsed-time for :pendulum at :length as timing
  output timing
]

do time-pendulum P1 "0.50 m" as first-timing
require first-timing has duration and time unit
```

Here `result` in the `must` rule means the item returned at a successful procedure exit.
The language need not require strong static types for every value: `require` can guard an
input or result before use, and `must` can state a checkable obligation on the result. Such
lines need actual validation and run evidence; writing them is not proof that the conditions
held. An unknown check remains **undetermined** under the [semantic core](core.md).
Procedure inputs and result names belong to each call; only an explicit `output` passes a
result back. State changes to scientific items are explicit run events rather than silent
changes through a name. In the first runnable slice, an `as` name cannot duplicate a
visible result or one of the procedure's inputs. Separate sibling blocks may use the same
result name because neither block can see the other's result. Naming rules for proposed
constructs such as standards and agents still need definition.

### Comments and descriptions

The proposed comment forms are `;` to the end of a line, following
[Logo](https://people.eecs.berkeley.edu/~bh/docs/html/usermanual_1.html), and
`#| ... |#` across lines, following
[Racket](https://docs.racket-lang.org/reference/reader.html). Both are ignored by the
checker. An optional `about "..."` field retains explanatory text on an investigation,
procedure, stage, or other named part, without making it an obligation or an LLM prompt. An
ordinary quoted string may span several lines; no second quote form is needed. `about` is
recognized in that field position, leaving phrases such as `ask agent ... about paper`
unambiguous.

ScienceLogo uses [CommonMark Markdown](https://spec.commonmark.org/) for `about` text:
ordinary prose stays readable in source, while established syntax provides emphasis,
lists, links, and code. A parser can retain the text without rendering Markdown during a
run. Richer dialects such as [MyST](https://mystmd.org/spec/overview) may be useful for a
separate documentation site, but are not required inside a ScienceLogo workflow.

`about` describes a workflow or one of its named parts. Its first paragraph should
briefly explain the part's purpose. Further prose may explain rationale, assumptions, or
limitations. Headings are optional. The facts available to
[external publication tools](workflow-documentation.md) come from named activities,
inputs, outputs, agents, `require` rules, `must` rules, and observed run events. Authors
should not have to copy those formal facts into Markdown. An `about` paragraph cannot
satisfy a scientific obligation or establish that an LLM suggestion is true.

For example, the procedure could begin with:

```text
to time-pendulum :pendulum :length [
  about "Time ten swings and record the pendulum length and duration with units.

## Why
Repeated timings allow periods to be compared across lengths."
  require :pendulum is a pendulum
  require :length has a unit
  ...
]
```

`about` stays optional in this draft. Whether a shared investigation must have a summary
can be decided with the rules for publishing workflows.

### A small vocabulary for conditions

These forms have different jobs. The runnable slice currently implements
`must do name` and `must stages in order ["First" "Second" ...]` as structural
obligations checked against the written method. The broader forms below are
still design work, and a prototype
should preserve their distinctions:

| Form | Meaning | When it is checked |
| --- | --- | --- |
| Named declaration, such as `prompt` or `criteria` | Introduce a named method item, its structure, and its references. Declaring a claim does not establish its truth. | Validate its structure and references before a run. |
| `require condition` | Guard the sequence at this point. If false or unknown, suspend later actions in that sequence and record why; a specified resolution path may supply missing evidence. | When execution reaches the gate, with a check event in the run. |
| `must rule` | State an obligation over the containing scope, including later paths and outcomes. It does not itself advance the procedure. | At its declared checkpoint, using static analysis, run evidence, or human review as appropriate. |
| `check condition` | Ask for an immediate evaluation and retain the result and evidence. This is an activity in the sequence. | Exactly where the command appears in a run. |

Reusable standards also need an advisory rule distinct from `must`. An
unmet recommendation may have a priority and supporting reason, without becoming a
conformance violation. `should` is a possible word. Its spelling, the syntax for
linking a concrete workflow to a standard, and the form of a generic comparison
remain open. A comparison should return structured results identifying each condition,
target, applicability, outcome, priority where relevant, and evidence.
One candidate is `use standard "Pendulum timing" version "0.1"` in an investigation to
record the intended specification, followed by an `assess` operation on an identified
method, run, or report. The link alone neither executes default procedures nor asserts
compliance. Resolution to a library source, version locking, and the exact `assess`
grammar still need design. The resolved reference and content identity must be retained
with the method and each assessment, as described in the
[versioned standard contract](core.md#versioned-standards).
Stage headers and supplied default procedures in a standard make a template readable;
they do not silently become `must` rules. Required presence, ordering, output, or use
must be declared. Advice and open choices remain distinct from those requirements.

`declare` could be a general spelling for introducing a named item, but `prompt "screen-v1"`
and `criteria "eligible studies"` are shorter and tell a reader what kind of item is being
introduced. A future `declare` form needs a concrete use that these named forms cannot
express. `assert` could name the immediate test, but it can also sound like a claim is being
pronounced true. `check` better invites a **satisfied**, **violated**, or **undetermined**
answer. If `assert` is ever added, it must have an explicit checking meaning and recorded
evidence; it must not promote a model suggestion to scientific fact.

For example, a procedure may say `require full text of paper is available` before it asks
an extractor, then `check every suggested finding has a source passage` after the answer.
A surrounding `must every verified finding links to its source passage` still applies if the
procedure fails, is skipped, or follows another path. The check event says what was tested
in this run. The `must` rule says what every applicable run owes. A failed or undetermined
`require` needs an explicit handoff or stop; a failed `check` needs its result handled or
retained as a violation, according to the containing procedure's policy.

The readable text after `must` cannot be arbitrary prose if the language promises a check.
Broader obligations need a small, explicit grammar for relations such as `before`,
`has`, `from`, and `when`. A sentence outside that grammar must be rejected or marked as a
human assessment, never silently treated as a verified rule. Each parsed obligation needs:

| Part | Meaning |
| --- | --- |
| Scope and subject | Which papers, activities, decisions, or runs the rule covers. |
| Trigger | When the rule applies, such as an agent returning `unsure`. |
| Required condition | The order, value, provenance, or human action required. |
| Checkpoint | When to evaluate it, such as before a final decision or at the end of a run. |
| Evidence | The item fields and run events needed to report satisfied, violated, or undetermined. |

For example, `must when screening suggestion is unsure [ human decision before final
decision ]` is a scoped rule. A checker can verify that the named events occurred in order
for each affected paper. It cannot decide whether the human's scientific judgment was good.
The proposed `must` form may also contain a nested group of such rules. A simple beginner's
rule remains one line: `must record a time unit for every duration`.

A list can make a standard's structure easier to read. The implemented
`must stages in order ["Observe" "Compare"]` checks top-level stage presence and
source order in one workflow file; it does not assess a run or a separate standard.
`must all [ ... ]` remains a candidate for independent required conditions whose
order is irrelevant.
`must every timing has [pendulum length length-unit swing-count duration time-unit]`
similarly lists required fields without ordering them. The rule supplies the list's
meaning; brackets alone do not imply an obligation or an ordering rule. Each condition
still needs its own
inspectable finding and evidence. An `about` paragraph may contain Markdown numbered
or bullet lists, but those remain documentation, not executable conditions.

## A prompt is a named method component

An LLM prompt needs a stable name and revision, ordered instruction and task parts, named
input slots, and an expected answer shape. In a simple workflow, these can read like ordinary
instructions. A more detailed workflow can declare message roles, content kinds, examples,
and tool descriptions. The language should preserve the order and structure of all these
parts; it should not reduce the prompt to one opaque string. The exact wire format and role
mapping belong to the chosen model adapter and must be visible in the run record.

The following is a syntax sketch for one screening prompt. `context` inserts the named
material into the request at that position; it is not permission to read other material.
The agent setup separately defines what material is permitted. The answer shape states a
required format that a checker can inspect; it does not prove the answer is true.

```text
prompt "screen-v1" [
  instruction "Apply the supplied eligibility criteria to this paper."
  context criteria "eligible studies"
  context title of current paper
  context abstract of current paper
  question "Include, exclude, or unsure? Give a reason and a source passage."
  answer [
    decision one of include, exclude, unsure
    reason text
    passage from supplied title or abstract
  ]
]

settings "screen-settings" [
  output limit 300 tokens
]

agent "paper screener" [
  given criteria "eligible studies"
  given title and abstract of current paper
  model "screen-model"
  settings "screen-settings"
  prompt "screen-v1"
  suggest a screening decision
]

to screen-paper :paper [
  ask agent "paper screener" about :paper
  if unsure [ ask human "resolve uncertain eligibility" ]
  if include or exclude [ ask human "confirm or revise eligibility" ]
  if invalid or no answer [ ask human "resolve failed screening" ]
  record final decision
  must when screening suggestion is unsure [
    human decision before final decision
  ]
  must human decision before final decision
  must final decision has reason, decision maker, and source passage
]
```

The prompt name, settings name, criteria name, and agent name are references, so a validator
can reject an unknown name, a missing input, or a prompt that asks for context outside the
agent's allowed view. Names such as `screen-model` can be experiment parameters, but they
must resolve to a provider, concrete model identity or version, and supported options before
an agent call. Unsupported settings should be reported instead of ignored. Model parameters
belong to `settings`, not inside the prompt text; tools, memory, retrieval, retries, and
stopping rules belong to the agent's working environment.
That working environment is a named part of the scientific method, whether an
implementation calls it an agent setup or a harness. It should be understandable to a
scientist without exposing unnecessary adapter internals. A simple LLM call may have a
small environment; an autonomous agent may need more explicit permissions, memory,
retrieval, stopping, and handoff rules.

## What the run must retain

The named template is distinct from the **request actually sent**. Each agent call should
retain the resolved prompt revision and digest; bound slot values with source identities and
versions; ordered rendered messages and content parts; the actual model and adapter; all
resolved parameters, including adapter defaults; and the tools and permissions supplied.
If material is retrieved, shortened, omitted, or added by a tool or memory, record what the
model actually received and the decision that selected it. Later turns, tool calls and
results, retries, responses, validation failures, and stopping reasons belong to the same
trace. Where a provider cannot expose some internal behavior, mark it unknown.

Some source material may be access restricted. A run can retain a protected copy or a
controlled reference and digest, plus its provenance and access rule; a digest alone cannot
let a reviewer inspect the content. The run must never imply that the model saw the whole
investigation simply because the investigation contained it.

Checks happen at different times. Before a run, a validator can resolve names, confirm
input slots, inspect declared permissions, and check some possible ordering paths. During
or after a run, a checker can inspect actual context, event order, output fields, and human
handoffs. A scientific claim that a passage supports an answer requires human assessment
unless a specific accepted test exists. All checks report **satisfied**, **violated**, or
**undetermined** with their evidence, as defined in the [semantic core](core.md).
