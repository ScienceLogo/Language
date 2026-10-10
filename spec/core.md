# ScienceLogo semantic core (draft)

**Status:** design contract for the first prototype, not adopted syntax or a complete
language specification. The [design principles](design-principles.md) state the wider
scope and learning tests; the [example workflows](../examples/README.md) explore readable
wording. This document states the minimum meaning the prototype should preserve.

## What ScienceLogo must distinguish

ScienceLogo must keep three related things distinguishable:

1. **Scientific context:** the things, relationships, and available knowledge that make
   an activity meaningful.
2. **Specified method:** the activities and possible paths, together with obligations they
   must honour.
3. **Observed run:** the actions, inputs, outputs, decisions, exceptions, and evidence that
   actually occurred.

The specified method may include loops, branches, agent actions, and human interventions.
An observed run follows one path through it. A run record must not turn an intended action
into a claim that it happened.

## Workflow as the abstract core

A **workflow specification** describes possible work and the conditions on that work. An
investigation is a workflow with a research question; a reusable procedure describes a
smaller piece that a workflow may call; a standard constrains workflows of a stated kind.
An observed run is an occurrence of a specified workflow, not another specification.
This distinction lets the same method be assessed before any work occurs and then compared
with several observed runs.

The language needs these abstract types and relationships. They describe structure; they
do not prescribe a catalogue of scientific steps or domain data types.

| Abstract type | Role in a workflow |
| --- | --- |
| Workflow | Contains possible activities, paths, conditions, and references to reusable procedures. It can be nested or reused without implying that source order is execution order. Its source and revision matter when it is shared or assessed. |
| Activity | Describes work or a decision that may occur. It has possible inputs and outputs, an actor or authority where relevant, and possible success, failure, and handoff paths. A declaration is not a claim that it occurred. |
| Scientific item | Something an activity can use, create, change, or assess. Its scientific kind and fields come from a library or investigation; its origin, status, and identity must be available when a reference or run trace needs them. |
| Actor | A person, program, or agent that may perform an activity, with the authority and context needed for that role. |
| Condition | A requirement, guard, check, or advisory rule with a target, scope, checkpoint, and evidence needed to assess it. These forms have distinct effects. |
| Relation | A typed link among workflow elements: containment, use or production of an item, required order, dependency, influence, or evidential support. The link's kind determines what can be inferred from it. |
| Run event | A recorded occurrence of an activity or decision, linked to its specification and to the actual actor, inputs, outputs, and evidence. |
| Assessment | A finding about a specified workflow, observed run, or report under an identified condition or standard. It records what was checked and what remains undetermined. |

This model does not require an author-written name for every activity or item. An element
needs an identity when another element, condition, standard, run event, or publication
points to it; the representation may assign that identity within an identified method
version. A reusable procedure has an author-written name because it can be called; a stage
has one because it is a readable reference and checkpoint boundary. Other work can remain
unnamed in the source. A reference must identify its target unambiguously; an assessor must
not infer a target from nearby prose or source position alone.

Relations carry different meanings. Containment groups a workflow; input and output links
describe what an activity may use or produce; an order link constrains possible execution;
a dependency says what another activity or result relies on; an influence link supports
tracing the possible effects of a missing or uncertain source. None of these links alone
asserts that work happened or that a scientific claim is true. A stage groups part of the
workflow for reading and checkpoints, but is not itself an activity. `to` defines a
reusable procedure, while `do` calls it or executes a block.

An uncertainty source may concern an activity, an item, or a relation. A structural
assessment can distinguish a required source that was **declared** from one that was
**omitted**, then follow stated dependencies to identify possibly affected work. Its
magnitude, scientific importance, or claim of negligibility needs a stated method and
evidence; those judgments do not follow from the abstract workflow types alone.

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
The runnable assessor can detect missing names and follow those links; it does not yet
represent the full workflow types, their inputs and outputs, or run events. In the
[plant-growth example](../examples/plant-growth.md), measuring and comparing are activities,
plants and dated observations are items, and the date rule is a condition. Neither example
requires the language to define what every scientific activity or item must be called.

### Structural validation contract

The next reader and assessor slice should preserve these checks before adding discipline
specific types:

- Every reference resolves to one element of the expected abstract type. An input or
  output link targets an item; an order link targets activities. A wrong-type or ambiguous
  reference is a structural error.
- A workflow may contain unnamed activities and items. A required named role is checked
  only when an interface, standard, or another explicit condition asks for it.
- Declaring two activities does not order them. Only sequence, control flow, or an explicit
  order relation can require one to happen before the other.
- A missing required element or relation can affect dependents through stated links. The
  assessment reports the missing source and affected targets separately. Declaring an
  element or a `provide` reference does not prove that its work occurred or succeeded.
- A method assessment uses specified structure; a run assessment uses observed events;
  scientific adequacy may remain undetermined. Each finding identifies its target and the
  condition that produced it.

These checks can be exercised on the assessor workflow and the plant investigation. They
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
| Investigation | Names the research question and scopes its context, method, obligations, and runs. |
| Stage | A named section of executable method commands, beginning at a header and ending at the next header at the same nesting level or the enclosing block's end. It supports documentation, references, and checkpoints without performing an action or check itself. |
| Agent setup | Defines the model, prompt, settings, knowledge and context it may receive, tools and permissions, memory scope, and stopping or retry rule for an agent activity. |
| Obligation | A condition stating what must hold, with a scope, checkpoint, and evidence that could establish or refute it. It can apply to an activity, a path, or a whole run. |
| Standard | A reusable workflow specification in a library: stages, relationships, conditions, open choices, and optional default procedures. A research protocol can be represented this way. |

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
The current syntax sketch makes order explicit inside a `do` block and through stage
headers on a path. A form for independent or partially ordered activities remains to be
designed; their order should not be invented from source placement or a publication's
reading order. A `must` rule about order checks a condition; it does not schedule the
activities itself.

For example, measuring plant heights and recording weather might be independent, while
comparing growth needs both results. The method should be able to express those two
dependencies without forcing an order between measurement and weather recording. A run
then shows which order or overlap actually occurred. The syntax for this relation is
still open.
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

## Trace 1: measuring a plant

This trace gives concrete meaning to the [beginner sketch](../examples/plant-growth.md).
The names and values below are illustrative.

**Starting context.** Plant `P1` belongs to the sunlight group. The activity concerns
height in centimetres on measurement date `2026-06-01`. Learner `H1` has a ruler and may
measure and record `P1`. The investigation contains no height observation for that plant and
date yet.

**Specified method.** `H1` measures `P1`, then records its height and measurement date. The
obligation is: every retained height observation has a plant identity, measurement date,
numeric value, and unit. The check runs when an observation is recorded and again before a
comparison uses it.

**Observed run.** All event times below are on `2026-06-01` in UTC.

| Run event | What happened | Resulting state and retained evidence |
| --- | --- | --- |
| `E1` Measure, `09:00Z` | `H1` measured `P1` with the ruler and observed `12.4 cm`. | A measurement result is available to record; `P1` remains in the sunlight group. |
| `E2` Record, `09:05Z` | `H1` recorded observation `O1`: plant `P1`, date `2026-06-01`, height `12.4`, unit `cm`, based on `E1`. | `O1` is retained and linked to its plant, group, measurement event, and recorder. |
| `E3` Check, `09:05Z` | The checker inspected `O1` against the obligation. | **Satisfied** for `O1`: all required fields are present. No claim about measurement accuracy is made. |

**Invalid run.** `E1` measures `P1` as above. An alternative `E2` records `12.4 cm` for `P1`
but leaves the *measurement date* empty. At `E3`, the checker reports **violated**, identifies
`O1` and its missing date, and prevents a comparison from treating that observation as
complete. A file creation timestamp is not a substitute for the date of measurement. The
learner can supply the missing date through a recorded correction; the original incomplete
record remains inspectable.

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

The first runnable slice already resolves `do measure-plants` when its `to measure-plants`
definition appears later in the same investigation and reports an unresolved call
before running anything. A later method representation should expose both the call site
and the procedure it names, so a publication tool can follow the reference without using
source order as an identifier.

This contract leaves the surface syntax, exact intermediate representation, execution
engine, and standards for scientific judgment open. The examples should be revised as those
decisions are tested with scientists and learners.
