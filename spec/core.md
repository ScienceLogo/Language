# ScienceLogo semantic core (draft)

**Status:** design contract for the first prototype, not adopted syntax or a complete
language specification. The [example workflows](../examples/README.md) explore readable
wording; this document states the minimum meaning the prototype should preserve.

## What ScienceLogo must distinguish

ScienceLogo must keep three related things distinguishable:

1. **Scientific context:** the named things, relationships, and available knowledge that make
   an activity meaningful.
2. **Specified method:** the activities and possible paths, together with obligations they
   must honour.
3. **Observed run:** the actions, inputs, outputs, decisions, exceptions, and evidence that
   actually occurred.

The specified method may include loops, branches, agent actions, and human interventions.
An observed run follows one path through it. A run record must not turn an intended action
into a claim that it happened.

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

## Core concepts

| Core concept | Minimum meaning |
| --- | --- |
| Investigation | Names the research question and scopes its context, method, obligations, and runs. |
| Scientific item | Has an identity, kind, origin, and status. It may be a plant, source, dataset, criterion, observation, claim, model, or decision. A suggestion is not automatically an accepted finding. |
| Actor | A person, program, or agent with a named role and authority for an activity. |
| Activity | Names its actor, readable inputs, permitted actions, possible outputs, and effect on the investigation's state. Its failure and handoff paths matter too. |
| Agent setup | Defines the model, prompt, settings, knowledge and context it may receive, tools and permissions, memory scope, and stopping or retry rule for an agent activity. |
| Obligation | Names what must hold, its scope and checkpoint, and what evidence could establish or refute it. It can apply to an activity, a path, or a whole run. |
| Run event | Records one observed activity or decision, including its actor, actual inputs and context, outputs, state change, time, and evidence references. Corrections retain the earlier record. |

An activity changes the state of named scientific items and emits run evidence. The same
written activity may have different outcomes: a measurement can be missing, an agent can be
uncertain, and a human can reject a suggestion. ScienceLogo therefore needs to represent
possible transitions, not assume one predetermined result.

An agent's view is narrower than the investigation's context. The method says what it *may*
receive or use; the run says what it *did* receive or use. Its output starts with the status
of a generated suggestion. A later human or machine activity may accept, revise, or reject
it, leaving a trace of that decision.
Repeated calls may return different suggestions. Each attempt, its actual request and
context, and its outcome must remain separately inspectable.

An obligation has one of three reported outcomes: **satisfied**, **violated**, or
**undetermined**. Each outcome names the check and its evidence. A checker may establish
that a required field exists or that human review occurred. Whether a cited passage truly
supports a scientific claim may remain undetermined until a person assesses it. The language
must not report an undetermined scientific judgment as satisfied. Checks depend on the
evidence a run records; they cannot prove that an unrecorded action never occurred.

The draft [prompt and obligation design](prompts-and-obligations.md) develops how `must`
rules, named prompt parts, model settings, agent context, and actual requests fit together.
The [LLM variation design](llm-variation.md) describes repeated attempts, context
dependence, and the evidence needed to inspect model-assisted work.

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

## First prototype acceptance checks

The first Racket prototype should be able to represent both starting contexts, specified
paths, obligations, and observed events without flattening agent suggestions into human
decisions. It should report the two invalid runs above with the relevant item and missing
evidence. Its inspection output should show what was prescribed, what path was specified,
and what the run actually did. For the agent trace, it should also distinguish the declared
agent view from the supplied context, expose the model call as an attempt, and reject a
recorded final decision that bypasses the required human authority. The representation
should allow a later attempt or run to be linked and compared without claiming that matching
prompt names guarantee matching requests.

This contract leaves the surface syntax, exact intermediate representation, execution
engine, and standards for scientific judgment open. The examples should be revised as those
decisions are tested with scientists and learners.
