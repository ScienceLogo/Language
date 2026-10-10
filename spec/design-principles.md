# ScienceLogo design principles (draft)

**Status:** goals and tests for the language, not adopted syntax or a claim that the
current reader implements them. The [semantic core](core.md) defines the intended
context, method, and run records; the [first runnable slice](first-slice.md) lists
what works today.

## Scope of a scientific workflow

ScienceLogo should describe the whole investigation: its question, sources and datasets,
transformations, analysis, choices, claims, and evidence. AI may help at many points,
including search, screening, extraction, coding, interpretation, and writing. The same
language must also work for investigations without AI. Its purpose is to let people
inspect the method, test stated obligations, trace results to evidence and decisions,
repeat or compare runs, and examine sensitivity, robustness, and possible bias under
alternative choices. These capabilities support scrutiny; they do not establish that a
scientific conclusion is true.

Knowledge synthesis from unstructured sources is one demanding test case because it
exposes selection, evidence, review, and bias. Modelling or another kind of analysis
must also test the design, so review-specific assumptions do not become requirements
for every workflow. A named [standard](core.md#standards-as-workflow-specifications)
can express a research protocol, but a workflow need not start from a formal protocol
or require preregistration. The scientist remains responsible for the question,
criteria, method, and conclusions.

## Learn science through readable procedures

ScienceLogo follows Logo's approachable words, small named procedures, interactivity,
and vocabulary that learners can extend. It need not copy the exact syntax of an
existing Logo dialect. Its claim to be a Logo dialect should be tested by whether a
learner can read a command, try it, see its effect, and build larger methods from small
parts. Scientific activities, obligations, evidence, and run records require meanings
that ordinary turtle movement alone does not supply.

The [young Galileo plant investigation](../examples/plant-growth.md) is a progression
test. A learner starts by observing and comparing plants, then adds dates, units,
controls, missing observations, uncertainty, and evidence behind a conclusion. The
same language should later accommodate AI assistance without making the first lesson
hard to read. A turtle may help teach what an action changes: `forward` changes its
position, while `measure height` should create an observation in an investigation.
The turtle is an optional teaching example, not a required entity in ScienceLogo.

Named, nested parts should give a larger investigation structure while keeping each
small procedure understandable. This borrows the useful grouping idea from object
oriented programming without requiring classes or inheritance. Procedure calls,
stages, and scientific items must retain their distinct meanings; nesting alone must
not turn a stage label into an executable procedure.
Author-written names serve references and reuse; ordinary activities and items need not
all carry one.
The [abstract workflow core](core.md#workflow-as-the-abstract-core) defines the
structural types that a method, standard, and assessor should share.

## Make relevant context visible

People can sometimes resolve an underspecified instruction from shared experience.
An AI activity cannot be assumed to share that context. Before it acts, the method
should identify or elicit the criteria, sources, assumptions, units, and authority
needed for the task. A short beginner program can remain short if the language asks
for missing information; any default or interactive answer that supplies context
must be visible in the specified method and observed run. Hidden context must not
quietly change the scientific meaning of an activity.

An agent's working environment, sometimes called a harness in an implementation,
is its permitted view of and access to the investigation. It includes the resolved
model and settings, instructions, retrieval sources, available tools and permissions,
memory scope, retry and stopping rules, and human handoffs. A simple call may need a
small environment; a more autonomous agent needs a fuller one. A scientist should be
able to inspect and explain it in ordinary language. The method records what an agent
may use; the run records what it actually received, retrieved, inferred, and did.
Material can retain its origin and status without treating a generated suggestion
as accepted knowledge. Some evidence may require controlled access instead of open
publication.

## Preserve meaning across tools

ScienceLogo should produce a machine-readable account that preserves scientific
context, prescribed conditions, specified procedure, and observed events as distinct
parts. It must represent loops, branches, exceptions, and human interventions; a
simple acyclic step graph alone would lose some of that meaning. A typed intermediate
representation is a possible implementation, but its exact shape and interchange
format remain open. Tools must not turn an intended action into a claim that it
happened or an unverified suggestion into a finding.

Racket is the current tool for implementing the reader, validator, and language
semantics. That does not require scientists to write an entire analysis in Racket or
future tools to use Racket internally. ScienceLogo is a language project in its own
right.

## Tests for later semantic prototypes

Beyond the [current control-flow slice](first-slice.md), a prototype should be tested
against both knowledge synthesis and modelling or analysis workflows. It should:

- let readers distinguish an obligation from an action and understand the purpose
  of nested, named parts;
- represent order, dependencies, branches, loops, permitted exceptions, and human
  review without silently forcing every method into one sequence;
- expose context that an AI activity needs, including how missing information was
  resolved, and distinguish allowed access from actual access;
- separate checks possible before execution from those needing run evidence or human
  scientific judgment;
- reject invalid ordering or missing obligations where the evidence allows, and
  produce an inspectable link from each condition to the activities and events it
  concerns; and
- preserve the distinction between a method, an observed run, and a comparison of
  alternative choices or runs.

The wording and interpretation of these results should be tested with scientists and
learners, not only with parser tests. The [semantic core's acceptance checks](core.md#acceptance-checks-for-a-later-semantic-prototype)
give concrete plant and agent traces for this work.
