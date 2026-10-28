# ScienceLogo design principles

These principles explain the purpose and design rationale of ScienceLogo.
The [specification](README.md#language-specification) and
[manual](../scribblings/sciencelogo.scrbl) define the language rules.
The principles guide readable workflow descriptions; they do not add syntax
or requirements to individual workflows.

## Human understanding and supervision

ScienceLogo makes scientific methods understandable and inspectable by
people. Its scope includes questions, data, procedures, assumptions,
hypotheses, conclusions, and the conditions under which work is described.
AI can participate in search, screening, extraction, analysis,
interpretation, or writing. A workflow can also contain no AI at all.
Human supervision depends on being able to inspect what information is
available, who is designated to act, and what changes the method describes.

The language supports assessment of scientific adequacy by making the
relevant information expressible and accessible. It does not define
scientific adequacy. Protocol conformance, bias analysis, quantitative
uncertainty analysis, and judgments about evidence belong to independent
applications and scientists.

## Learn through readable procedures

ScienceLogo draws on Logo's approachable words, small named procedures, and
vocabulary that learners can extend. It has its own syntax and scientific
purpose. Turtle movement is an optional teaching example.

The [young Galileo pendulum case](../examples/pendulum-period.md) starts with
one question: does the period change as a pendulum's swing becomes smaller?
A learner can describe a timing plan, add repeated observations and
uncertainty, and relate a conclusion to a hypothesis. The following question
can examine the effect of pendulum length. This progression keeps the first
lesson approachable while allowing the method to become more detailed.

A procedure is a reusable definition; a call invokes it. A stage is a
checkpoint and section of the method. Values describe the information a
method uses and produces. These roles remain distinct even when their
source is nested. Interfaces provide reusable structures and requirements
without a separate class system.

## Make relevant context visible

The [context sets](context.md) distinguish information designated as
available, the relevant physical or digital environment, and possible
influences considered when interpreting the work. They apply to human and
AI activities. Paired stages declare entry and exit state; named input and
return locations make described changes inspectable.

For an AI activity, information can include a prompt and supplied material.
The environment can describe the model, settings, tools, and memory setup.
Considered factors can include text order, truncated context, and variation
between attempts. These are values and records supplied by the workflow or
its libraries. The language does not impose a separate scientific data
model for AI.

A performer identifies who or what is designated to carry out a
state-changing call. A resource identifies data outside the workflow.
Naming either does not establish that an activity occurred or that data
was transferred. A specified context and an observed context are distinct.

## Keep scientific meaning in workflows and libraries

The language supplies structure: procedures, stages, values, references,
control flow, interfaces, propositions, and uncertainty descriptions.
Libraries can define domain-specific objects and reusable pieces of a
method. A protocol can be expressed through a versioned interface with
nested requirements and mapped workflow parts.

Declaring a requirement makes it available for inspection. A structural
check can establish that a required field or mapping is present; a
scientific assessment must examine its meaning and adequacy. A conclusion
nested under a hypothesis records which hypothesis it answers without
establishing that the conclusion is supported by evidence.

## Preserve meaning across spellings and tools

Compact and verbose source express the same language, including when mixed.
Normalization preserves comments, strings, explicit parentheses, and
original source locations while producing compact source for parsing and
checks.

Readers preserve method structure, resolved references, conditions, and
human explanations. A branch remains a branch, a call remains linked to its
procedure, and a declared activity remains distinct from an observed event.
Other tools can inspect these relationships without treating an intended
activity as evidence that work happened.

Racket provides the reference reader, interpreter, and structural assessor.
The specification also supports readers and applications written in other
languages. Scientific applications and publication tools are independent of
the language package.
