# ScienceLogo semantic core (draft)

**Status:** design contract for the first prototype, not adopted syntax or a complete
language specification. The [design principles](design-principles.md) state the wider
scope and learning tests; the [example workflows](../examples/README.md) explore readable
wording. This document states the minimum meaning the prototype should preserve.

## What ScienceLogo must distinguish

Every investigation has a **specified method**: the activities and conditions it
describes. A particular use case may also supply scientific context or a record of work
that occurred. These records stay distinct when present. A written activity is not
evidence that it happened, and an assessment must identify which record it examined.
No workflow needs an actor, agent setup, or run record merely to be representable.

## Workflow as the abstract core

A **workflow specification** describes work and the conditions on it. An investigation
is a workflow with a research question; a reusable procedure describes a smaller piece
that a workflow may call; a standard constrains workflows of a stated kind. A call of a
procedure is an activity that refers to that definition. A stage is a named section and
checkpoint, not a callable procedure or a new variable scope.

The shared workflow representation has five abstract elements. They describe structure
without prescribing a catalogue of scientific steps or domain data types. A workflow
uses only the elements relevant to it.

| Abstract type | Role in a workflow |
| --- | --- |
| Workflow | Holds the method's elements and references to reusable definitions. It has an identity and revision so a later assessment identifies the method it checked. |
| Activity | Describes one operation or call in a method. Its presence in a method does not establish that it occurred. |
| Item | A named or assigned input, result, or other thing an activity uses or produces. Libraries or investigations provide scientific kinds and fields when needed. |
| Relation | A typed link between elements, such as containment, call, use, production, dependency, or required order. Syntax can establish the link through names, nesting, or sequence without a separate relation command. Its kind determines its meaning and valid endpoints. |
| Condition | A rule with a target and scope, and a checkpoint and evidence requirement when its check needs them. Requirements, guards, and advice can use conditions with different effects. |

**Assessment is an operation and its result, not a workflow element.** The assessor
examines an identified representation under a condition or structural rule and returns
findings with outcomes and their basis or gap. The `assessment` record in the Racket
implementation is that result. It is separate from the method records it examines.

Actor, context, observed run, and provenance information are introduced only for use
cases that need them. For example, an AI activity may need a declared view and an
observed request to assess what it received; an investigation without AI need not
supply those records. These are extensions of the representation, not prerequisites
for every method. The core does not prescribe scientific item fields, uncertainty
categories, or a particular analysis of bias.

The current Racket slice represents an investigation with `workflow-model`, its stage
headers with `stage-model`, its calls and commands with `activity-model`, named inputs
and results with `item-model`, and explicit links with `relation-model`. An interface's required parts become
`condition-model` records, as do an investigation's `must do name` and
`must stages in order ["First" "Second"]` rules;
`assess-workflow` returns an `assessment` with checks and findings. This implements
only part of the contract: named inputs and results are value slots, and arbitrary
scientific item kinds and conditions are not yet readable ScienceLogo syntax. The
assessor checks method structure, reachable required calls, ordered stage requirements,
and interface declarations, not scientific adequacy.

This model does not require an author-written name for every activity or item. An element
needs an identity when another element, condition, standard, run event, or publication
points to it; the representation may assign that identity within an identified method
version. A reusable procedure has an author-written name because it can be called; a stage
has one because it is a readable reference and checkpoint boundary. Other work can remain
unnamed in the source. A reference must identify its target unambiguously; an assessor must
not infer a target from nearby prose or source position alone.

Relations are part of the meaning of ScienceLogo syntax, even when no relation keyword
appears. In the current slice, `do collect as observations` names a result and
`do analyze observations` uses it as an input. The second call therefore depends on the
first through that result. The reader checks that the result is visible where it is used;
the model records production, use, and the resulting dependency. A `do name` call links to
its `to name` definition even when that definition appears later in the source. Nesting
specifies containment, and executable commands in a workflow or `do [ ... ]` block run
in order. These are different typed relations, not interchangeable claims that work
occurred or that a scientific conclusion is true.

The same principle must extend to larger structure. The optional `workflow "title"`
header names the file and creates no extra bracketed scope. A stage header assigns a named
section and checkpoint to the following forms without performing an activity or imposing
an extra execution order. When workflows are composed, the composition syntax must state
which workflows are linked, how one workflow's results become another's inputs, and which
sequence is required. The current reader treats one file as one workflow and supports
stage headers; workflow composition syntax remains open.

An uncertainty source may concern an activity, an item, or a relation. A library can
state what must be declared and how to assess it. Its magnitude, scientific importance,
or claim of negligibility needs a stated method and evidence; those judgments do not
follow from the abstract workflow elements alone.

The abstract types remain the same across disciplines. A library may describe a particular
kind of observation, dataset, model, prompt, or report, together with its fields and
specialized checks. A standard may then require typed elements and relations, including
named ones where a protocol needs them. The language supplies the structural types,
reference rules, and general assessment logic; the library or investigation supplies
scientific meanings and conditions. An interface can require a named capability without
turning that name into a built-in workflow type.

The [assessor self-description](../examples/meta-assessor/README.md) is a small test of
this separation. Its workflow is the assessment process; parsing, library resolution,
interface checking, impact tracing, and reporting are activities named by that particular
interface. Source files, parsed declarations, and findings are possible items. The
`affects` links currently encode only a narrow dependency between required named parts.
The runnable assessor can detect missing names and follow those links. The current
method model represents procedures, calls, named inputs and results, and their
structural relations; it does not yet represent scientific measurements or run events.
In the [pendulum example](../examples/pendulum-period.md), timing and comparing are
activities, timing records are items, and the unit rule is a condition. Neither
example requires the language to define what every scientific activity or item must
be called.

### Structural validation contract

The reader and assessor should preserve these checks as the representation expands:

- Every reference resolves to one element of the expected abstract type. An input or
  output link targets an item; an order link targets activities. A wrong-type or ambiguous
  reference is a structural error.
- Each activity and item belongs to its stated parent. Its containment relation must
  identify that same parent.
- A workflow may contain unnamed activities and items. A required named role is checked
  only when an interface, standard, or another explicit condition asks for it.
- Declaring two activities does not order them. Only sequence, control flow, or an explicit
  order relation can require one to happen before the other.
- A missing required element or relation yields a finding tied to the explicit
  condition and target. Declaring an element or a `provide` reference does not prove
  that its work occurred or succeeded.
- An assessment identifies the representation it checked. The current assessor checks
  method structure; a later run assessment can use observed records when a use case
  supplies them. Scientific adequacy may remain undetermined.

These checks can be exercised on the assessor workflow and the pendulum investigation. They
do not require a fixed list of named steps for either one.

## What it means to account for AI

ScienceLogo must represent an AI activity as part of the scientific method, with its own
inputs, permissions, possible outcomes, and evidence. AI may participate in planning,
searching, selecting sources, preparing data, analysis, interpretation, and reporting, even
when it performs most of the operations in a workflow. The scientist needs a view of the
whole investigation, including the choices and claims made at each stage. The language and
its run representation should support these tasks:

| Task | What ScienceLogo must represent or check |
| --- | --- |
| Trace | Connect each attempt to the resolved model, prompt, settings, supplied context, tools, memory, output, validation, and later human or machine decision. Retain failed and discarded attempts. |
| Replicate and compare | State the conditions for a new run, link it to the earlier method and run, record any changed or unavailable condition, and compare outputs and decisions. The same method need not yield identical model text. |
| Control | Limit an agent's context, tools, authority, retries, and stopping conditions before use; check actual requests and events against those limits; route failures and uncertain cases through stated paths. |
| Evaluate | Distinguish a well-formed answer from a supported scientific judgment. Allow declared tests, repeated attempts, alternative choices, and human assessment without promoting model confidence or agreement to proof. |

These are language obligations, not just fields for a later log viewer. A validator should
inspect the specified method before execution, and a run checker should compare it with
observed events. If a provider hides a condition or the trace lacks evidence, the relevant
check reports **undetermined**, with that limit visible. An investigation without AI uses
the same concepts of activities, obligations, and evidence at a simpler scale.

## Humans first in AI science

People set the scientific conditions for the workflow and retain a way to inspect and
challenge its results, even when AI performs most of its operations. The declarative layer
states which sources and measurements are admissible, what evidence a claim needs, when
checks occur, which decisions need a person, and which uncertainties must remain visible.
The procedural layer states who or what performs each step and in what order. A run connects
the two by showing which
conditions held, which failed, and which still need judgment. These conditions apply to
human and AI activities alike, including stages that contain several nested procedures.
This is the sense of **“Declarative, not decorative”**: a stated condition has a scope,
checkpoint, and evidence for checking it.

An AI suggestion, a human decision, and a scientific claim have separate identities and
statuses. Moving a suggestion into a conclusion requires a recorded decision, its actor,
the supporting evidence, and any unresolved limitations. Human review may mean approving a
method, checking a sample, resolving a disagreement, verifying a cited passage, or deciding
whether a conclusion is warranted. The method must say which review is required and at what
point; a generic approval mark cannot establish that the underlying claim is true.

Human inspection should answer plain questions: What did the AI see and do? Which choices
did it make? What evidence supports each result? Who checked or changed it? What remains
uncertain, and what changed between runs? This readable account is an output of the language,
alongside the machine-checkable representation and run record. ScienceLogo supports scrutiny
of scientific claims; it cannot guarantee their truth.

## Roles built on the abstract core

| Role | Minimum meaning |
| --- | --- |
| Investigation | Names the research question and scopes its method. It can also identify context or runs when the investigation uses them. |
| Stage | A named section of executable method commands, beginning at a header and ending at the next header at the same nesting level or the enclosing block's end. It supports documentation, references, and checkpoints without performing an action or check itself. |
| Agent setup | Defines the model, prompt, settings, knowledge and context it may receive, tools and permissions, memory scope, and stopping or retry rule for an agent activity. |
| Obligation | A condition stating what must hold, with a scope, checkpoint, and evidence that could establish or refute it. It can apply to an activity, a path, or a whole run. |
| Standard | A reusable workflow specification in a library: stages, relationships, conditions, and optional default procedures. A research protocol can be represented this way. |

An assessment applying a named standard to a concrete method, run, or report retains
each condition's applicability, outcome, priority where relevant, and evidence or missing
evidence. Run events retain the actual actor, inputs, context, outputs, state change, time,
and evidence references; corrections retain the earlier record.

An activity specification describes possible changes to scientific items. An observed
occurrence records what changed and the evidence available for it. The same specified
activity may have different outcomes: a measurement can be missing, an agent can be
uncertain, and a human can reject a suggestion. ScienceLogo therefore needs to represent
possible transitions, not assume one predetermined result.

An agent's view is narrower than the investigation's context. The method says what it *may*
receive or use; the run says what it *did* receive or use. Its output starts with the status
of a generated suggestion. A later human or machine activity may accept, revise, or reject
it, leaving a trace of that decision.
Human collaborators may fill in an instruction from shared context, but an agent cannot be
presumed to know it. If the method needs a source, criterion, unit, or assumption that is not
yet specified, the language must make the gap visible and resolve it before the activity
uses that information. A supplied default or interactive answer becomes part of the method
and run record, not an invisible implementation choice.
Repeated calls may return different suggestions. Each attempt, its actual request and
context, and its outcome must remain separately inspectable.

An obligation has one of three reported outcomes: **satisfied**, **violated**, or
**undetermined**. Each outcome names the check and its evidence. A checker may establish
that a required field exists or that human review occurred. Whether a cited passage truly
supports a scientific claim may remain undetermined until a person assesses it. The language
must not report an undetermined scientific judgment as satisfied. Checks depend on the
evidence a run records; they cannot prove that an unrecorded action never occurred.

### Source order and method order

Named procedures and other declarations are resolved across their containing scope
before the method runs. A call may therefore refer to a procedure defined later in the
source. The validator checks the reference before execution. A result produced by an
activity, however, is available only after that activity occurs.

The order in which a document introduces components does not prescribe their runtime
order. The method describes calls, branches, loops, and any required dependencies; a
particular run records the path that occurred. A method need not be one straight line.
The current runnable slice makes order explicit among executable commands inside a
workflow or `do` block. Stage headers label sections and checkpoints; they do
not themselves schedule activities. A form for independent or partially ordered
activities remains to be designed. Their order should not be invented from definition
order, file order, or a publication's reading order. A `must` rule about order checks a
condition; it does not schedule the activities itself.

For example, measuring a pendulum's length and calibrating a timer might be independent,
while comparing periods needs both results. Passing both results to the comparison
expresses its dependencies. A syntax that allows the two preceding activities without
requiring an order between them remains open. A run then shows which order or overlap
actually occurred.
The proposed [`any order` group](prompts-and-obligations.md#activities-with-no-required-order)
tests the simplest case: both activities finish before comparison, with no order
between them. Its spelling and failure behavior remain open.

## Standards as workflow specifications

A research protocol can be represented as a reusable, possibly partial specification of
a workflow in ScienceLogo: a **standard** for that kind of work. It may name stages,
their order and conditions, required outputs or evidence, reporting duties, and decisions
that need human review. It can supply default procedures or leave parts of a stage open
for the scientist to design. A concrete investigation fills in choices with procedures,
agents, observations, and other activities. The same stage and rule constructs describe
the standard and the concrete method. Libraries can publish standards alongside reusable
`to` procedures.
Standards are available when a protocol applies; an investigation need not import one or
claim preregistration to be a valid ScienceLogo workflow.

A stage header in a standard provides a named place in the workflow template. Its
presence does not automatically make that stage mandatory in every concrete workflow.
The standard's explicit conditions say which stages or outputs are required, which are
recommended, and which are left open. A default procedure is available for reuse;
whether its use is required is likewise an explicit condition.

Strict and advisory guidance use the same structure. A specification can say what a
workflow **must** include or preserve and what it **should** consider, with priorities
where useful. For example, a library could encode the applicable
[PRISMA 2020](https://www.prisma-statement.org/prisma-2020) checklist requirements as
conditions on a review's method and reporting, while leaving research choices open
where the source does. The import identifies the library's source and revision; the
standard identifies the conditions it represents and how each condition is checked.
The library layout and import form are defined in [Libraries](libraries.md). Syntax for
declaring and applying a standard remains open.

A standard can serve as a template, provide declarations for validating a concrete
method, and direct checks on an observed run and scientific report. Applying it produces
a structured assessment. Both the standard and the concrete workflow are ScienceLogo
representations; the language can provide a general comparison operation, while a
library may add reusable `to` procedures for specialized checks. The method, run, and
scientific report must be inspectable as identifiable representations rather than raw
source text. A user
must be able to apply a named standard to a particular workflow; the same standard can
assess many workflows, and one workflow may be assessed against several standards.
The method's reference to a standard identifies a library source and exact version. It
expresses intent to use that specification, not a claim that its conditions are met.
Assessing a method, a run, or a report produces distinct findings against that same
identified source. A run assessment also identifies the method version and run examined.
Neither importing the library nor naming the standard executes its default procedures.

The assessment distinguishes **method coverage** (required stages and rules specified),
**run evidence** (which stages were reached and what happened there), and **scientific
judgment** (whether the work and evidence are adequate). A header in an unused library
procedure does not establish coverage, and a stage skipped in a run cannot count as
completed. Each condition has an applicability result, then an outcome such as
**satisfied**, **violated**, or **undetermined** where it applies. Applicability itself
may be established, ruled out, or undetermined. An unmet strict condition is a
conformance failure; an unmet advisory condition is a recommendation,
possibly with a priority. A standard may define finer grades or aggregation rules, but
the language must retain the individual findings and their evidence rather than reduce
them to an unexplained yes/no verdict. Each finding identifies the source condition,
target workflow version, and supporting evidence or gap.

The scientist may choose the actions and reasoning inside a stage wherever the protocol
leaves them open. Some specifications constrain a stage's composition, order, outputs,
reporting, or human review; others suggest useful components and priorities. Deviations
and amendments need recorded reasons and links to the affected specification, method
version, and run.

The draft [prompt and obligation design](prompts-and-obligations.md) develops how `must`
rules, named prompt parts, model settings, agent context, and actual requests fit together.
The [LLM variation design](llm-variation.md) describes repeated attempts, context
dependence, and the evidence needed to inspect model-assisted work.
The [workflow documentation design](workflow-documentation.md) describes the separate
readable accounts generated from a specified method and an observed run.

### Versioned standards

A standard has its own identity and version. When it encodes an external protocol, its
metadata also identifies that protocol's source and edition; the protocol edition and
the ScienceLogo encoding version are separate facts. Revising a rule, its priority, its
scope, or how it is checked creates a new standard version. A released version must stay
available unchanged so an earlier assessment can still be explained.

An investigation resolves each `use standard` reference to a particular library source,
standard name, version, and content identity. Its method record retains that resolution;
an assessment also retains it alongside the method, run, or report it examined. A later
standard version does not silently replace the one used by an earlier method or rewrite
an earlier finding. Reassessing the same work under a later version produces a separate
assessment. Condition IDs are stable within a version; a library can provide an explicit
mapping of related conditions across versions when their meaning changes. The spelling
of standard versions and the syntax for selecting a standard within an imported library
remain open. The library import form is defined in [Libraries](libraries.md).

## Trace 1: timing a pendulum

This trace gives concrete meaning to the [pendulum progression](../examples/pendulum-period.md).
The names and values below describe an illustrative run, not an experiment performed by
ScienceLogo.

**Starting context.** Pendulum `P1` has an adjustable length. Learner `H1` has a
stopwatch and can set the length, release the bob, and count full swings. No timing
record exists yet. Length is measured from the suspension point to the bob's centre.

**Specified method.** Set lengths of `0.50 m` and `1.00 m`, keep the release angle
comparable, and time ten full swings at each length. Record the pendulum and trial
identities, length and its unit, swing count, elapsed time and its unit, and the timer.
Compute each period as elapsed time divided by swing count, then compare the periods.
The record check runs before either timing is used in a calculation. Hand timing is
declared as an uncertainty source; its magnitude is not inferred from that declaration.

**Observed run.** All event times below are on `2026-06-01` in UTC.

| Run event | What happened | Resulting state and retained evidence |
| --- | --- | --- |
| `E1` Set length, `09:00Z` | `H1` set `P1` to `0.50 m` and measured that length. | The first trial's length and unit are available. |
| `E2` Time and record, `09:05Z` | `H1` timed ten full swings in `14.2 s` and recorded timing `T1`, the length, swing count, duration, units, and timer. | `T1` is linked to `P1`, the trial, and the timing event. |
| `E3` Time and record, `09:12Z` | After setting `P1` to `1.00 m`, `H1` timed ten full swings in `20.1 s` and recorded `T2` with the same fields. | `T2` is linked to its own trial and source event. |
| `E4` Check and compare, `09:15Z` | The checker found the required fields in `T1` and `T2`; the method computed `1.42 s` and `2.01 s` per swing. | The field rule is **satisfied** for these records. The comparison retains links to both timings and does not establish the accuracy of the hand timing. |

**Invalid run.** An alternative `E2` records `14.2` without a time unit. The checker
reports **violated** for `T1`, identifies the missing unit, and prevents that timing
from being used as a period. The learner can add the unit through a recorded
correction; the incomplete record remains inspectable. A declared hand-timing
uncertainty source also remains visible when the periods are compared.

## Trace 2: an agent screens a paper

This trace gives concrete meaning to one path through the
[synthesis sketch](../examples/knowledge-synthesis.md). The paper, passages, and model name
are invented solely for this example.

**Starting context.** Paper `S1` is a search result with status `found`. Its title is
“Canopy shade and summer thermal conditions in two parks.” Its abstract says, “We compared
summer thermal conditions beneath trees and in nearby open areas.” Criterion `C1` requires
measured outdoor summer air temperature and a comparison of places with different tree
cover. The full text is available to human reviewer `H2`; it has not been supplied to the
screening agent.

**Agent setup.** Agent `A1` may receive the title, abstract, and `C1`; it may suggest
`include`, `exclude`, or `unsure`, with a reason and source passage. It may not make the final
eligibility decision. It has no tools or memory from other papers and stops after one
suggestion. This illustrative run binds it to model `example-screen-model/1`, prompt
“Apply C1; return include, exclude, or unsure with a cited passage and reason,” and recorded
settings `temperature = 0`. The model name is fictional; a real run would retain the actual
model identity and version. These settings do not promise identical model text on repetition.

**Specified method and obligations.** Ask `A1` for a suggestion, then ask `H2` to confirm
or resolve it. If it says `unsure`, `H2` must resolve it before any final decision. Every
final screening decision must retain its decision maker, reason, and source passage. Every
agent use must retain its actual model, prompt, settings, supplied context, outputs, and
tool or memory events. The final decision is a human activity, distinct from the agent's
suggestion.

**Observed run.** All event times below are on `2026-06-02` in UTC.

| Run event | What happened | Resulting state and retained evidence |
| --- | --- | --- |
| `E1` Supply context, `10:00Z` | `A1` received exactly the title, abstract, and `C1`. The model, prompt, settings, empty memory, and absence of tools were recorded. | The agent's actual view is inspectable; the full text remains outside that view. |
| `E2` Suggest, `10:01Z` | `A1` returned `unsure`. It cited “summer thermal conditions beneath trees and in nearby open areas” and said the abstract does not identify the measured temperature type. | Suggestion `G1` is retained with status `generated`; `S1` is still awaiting a final decision. |
| `E3` Human review, `11:00Z` | `H2` read the full text passage “Air temperature at 1.5 m above ground was measured beneath trees and at open sites.” `H2` decided `include`, citing that passage and `C1`. | Decision `D1` is retained with actor, reason, and passage. `S1` changes to `included`; `G1` remains separately visible. |
| `E4` Check, `11:01Z` | The checker inspected the actual path and records. | **Satisfied** for required human review, decision provenance, and recorded agent access within the declared boundary. Scientific adequacy of the criterion and passage remains subject to human assessment. |

**Invalid run.** `E1` and `E2` occur as above. An alternative `E3` automatically changes
`S1` to `included` after `A1` returns `unsure`, with no human decision. At `E4`, the checker
reports **violated** for the review obligation and the agent's authority limit. It identifies
the missing human event and does not treat `G1` as the final decision, even if someone later
agrees with it.

## Acceptance checks for a later semantic prototype

A later prototype, beyond the [first runnable control-flow slice](first-slice.md), should
be able to represent both starting contexts, specified paths, obligations, and observed
events without flattening agent suggestions into human decisions. It should report the
two invalid runs above with the relevant item and missing evidence. Its inspection output
should show what was prescribed, what path was specified,
and what the run actually did. For the agent trace, it should also distinguish the declared
agent view from the supplied context, expose the model call as an attempt, and reject a
recorded final decision that bypasses the required human authority. The representation
should allow a later attempt or run to be linked and compared without claiming that matching
prompt names guarantee matching requests.

The first runnable slice resolves `do make-timing-plan` when its
`to make-timing-plan` definition appears later in the same investigation and reports an
unresolved call before running anything. The current method model also exposes the call
site and the procedure it names through an `invokes` relation, so another tool can follow
the reference without treating source order as an identifier. It does not yet represent
the timings or the observed run in this trace.

This contract leaves later surface syntax, the broader representation, execution
engine, and standards for scientific judgment open. The examples should be revised as those
decisions are tested with scientists and learners.
