# Workflow publication support (draft)

**Status:** design proposal, not an implemented research booklet generator. This
describes information ScienceLogo must expose to external publication tools. The
ScienceLogo language manual is maintained in this repository; templates for publishing
particular research workflows are separate from the language specification.

## Two records for one investigation

A reader needs to see both the **specified method** and an **observed run**, without
mistaking planned steps for completed ones. The [semantic core](core.md) already keeps those
records distinct. A publication tool can use both:

| Record | Question it answers | Source |
| --- | --- | --- |
| Method | What question is being investigated, how may the work proceed, who or what may act, and what conditions must hold? | The validated ScienceLogo source and its named method components. |
| Run | What actually happened in this attempt, which checks passed or failed, and what remains uncertain? | An identified method version plus recorded events, evidence, and check outcomes. |

The method record should expose the investigation's question and summary, declared
activity relationships and possible branches, actors and authority, inputs and outputs,
AI context and permissions, required human decisions, obligations and checkpoints, and
expected evidence.
Each item should refer to its source declaration. A model name in a method is a planned
choice or parameter; it must not be presented as the model actually used in a run.
If a reusable standard guides or assesses the method, the record should expose its
source and version, mapped stages, any default procedures used or changed, and the
conditions encoded.

The run record should expose the method version, run identity, actual path and timing, inputs
and resulting items, every agent attempt with its effective model, prompt, settings,
supplied context and tool use, human decisions and corrections, check outcomes with their
evidence, and unresolved or unavailable facts. Repeated attempts and discarded answers
remain visible. A missing trace or an **undetermined** check must be shown as such; the
generator cannot fill a gap with a plausible account. These requirements follow the
[AI trace](core.md#what-it-means-to-account-for-ai) and
[LLM variation](llm-variation.md) designs.
A run record should distinguish stage presence from work completed and evidence checked
against a named standard. It should expose applicable conditions, strict failures,
advisory suggestions, unresolved judgments, and their source conditions and evidence.

## What external publications need from the language

A research booklet may use an abstract with links to nested detail, or another structure.
Its template and reading order belong outside the language specification. ScienceLogo
must expose enough structured information for such a publication to be built:

| Language support | Information made available |
| --- | --- |
| Named, stable references | Investigation, stage, procedure, call site, agent, prompt, standard, condition, method version, run, event, and evidence identities. |
| Method relationships | Containment, procedure calls and their targets, possible paths, declared dependencies and order, inputs, outputs, and rules. A call resolves even when its declaration appears later in source. |
| Human explanation | `about` text attached to named parts, including an optional investigation summary, without imposing a page layout. |
| Scientific trace | Which activities and decisions actually occurred, their evidence and provenance, and which checks failed or remain undetermined. |
| Standard assessments | Exact standard source and version, condition identities, applicability, findings, and evidence gaps. |

These relationships allow an external tool to follow a reference from a summary to a
stage, a called procedure, a run event, or the evidence behind a finding. Shared
procedures and evidence can have several incoming references. The language must not
equate a component's identity with its source position or a page address. Missing or
ambiguous references should be reported during validation or publication. The exact
cross-reference notation for `about` prose and publication exchange format remain open.

## Where Markdown fits

`about` supplies readable scientific explanation in
[CommonMark Markdown](https://spec.commonmark.org/). A short opening summary is the
recommended convention when `about` is present. Optional prose can describe why a step
exists, assumptions that cannot be checked automatically, limitations, or how to interpret
an output. It may appear on an investigation, procedure, agent, prompt, or another named
component where a description helps. `about` has no effect on execution or check results.

### Which parts deserve an `about` description?

The attachment point is a **named part of the scientific method**, not every control
block. This keeps the source readable and gives generated documentation a stable subject.

| Part | Guidance for `about` |
| --- | --- |
| Investigation | Recommended for a workflow intended to be shared: summarize its scientific purpose, scope, and important limits. The research question in its name remains separate. |
| Named `stage` | Recommended for a section of work that gathers or changes evidence, delegates to AI, requires human judgment, or has several paths whose purpose needs explanation. The header provides a reference and checkpoint boundary; actors, actions, checks, and outputs come from the commands in that section. |
| `to` procedure | Useful when the procedure is reused, shared, or has a non-obvious scientific purpose. `to` defines a reusable sequence, which may be called as an activity; it need not be a pure function. Inputs and returned results come from its header and `output`. |
| Agent, prompt, criteria, fields, or settings | Add a description when a scientific choice or limitation needs rationale. The prompt content, permissions, criteria, and values stay in their structured declarations. |
| Anonymous `do`, `if`, `repeat`, or similar control block | Normally no `about`: the containing named part explains its purpose. Use a `;` comment for a local reading note. If a stretch of work is a distinct scientific stage that should appear in the generated account, start it with a `stage` header. |

An `about` field describes its immediately containing named part, or the stage whose
header it immediately follows. Comments are ignored by the checker and are not promised
a place in generated documentation. Thus an explanation that matters to a future reader
belongs in `about` on a named part. A `stage "name"` header labels the following section
until the next stage header at the same nesting level or the block's end. It has no action
or check of its own and does not change access to names. A `to` procedure defines a
reusable sequence; `do` calls or executes one.

Publication tools can choose their own format and layout. They should be able to derive
steps, inputs and results, actor roles, AI boundaries, human review, conditions, and
evidence from structured method and run records. An investigation's `about` text can
supply a human-authored summary. The tool may add factual orientation, but it must not
infer a scientific purpose or conceal failed and undetermined checks. If AI writes or
revises a summary, its contribution and any human review need a visible trace. A workflow
author should not have to maintain hand-written copies of formal facts in Markdown.

For example, documentation generated from the
[knowledge-synthesis workflow](../examples/knowledge-synthesis.md) could show that the
paper screener may receive only the criteria and a paper's title and abstract, that it
suggests a decision, and that a person makes the final eligibility decision. A run account
would then show the actual material supplied, the suggestion, the person's recorded
decision, and whether the review and source-passage obligations were satisfied. The first
description is a method promise; the second is evidence from one run.

This is a language capability, independent of where a publication is hosted. Related
scientific workflow formats, including [Workflow RO-Crate](https://about.workflowhub.eu/Workflow-RO-Crate/)
and its run extension, offer possible later export targets. Mapping to them requires a
separate design; choosing Markdown for `about` does not claim that ScienceLogo already
conforms to either profile.

## Open choices

- Define stable identities and links among source components, run events, and evidence.
- Define how to express independent activities and their dependencies without imposing
  an order through source placement alone.
- Define how stage occurrences are identified in traces, including when the same stage
  is reached in several iterations or procedure calls.
- Decide whether a published investigation requires an `about` summary. This draft keeps
  descriptions optional while the publication and validation rules are unsettled.
- Define the minimum run record before promising a complete generated run account.
