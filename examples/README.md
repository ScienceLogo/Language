# ScienceLogo design examples

The [first runnable slice](first-slice.rkt) is a small `#lang sciencelogo` program for
checking `to`, `do`, forward references, ordered blocks, and Logo's `print` command.
It prints a method reminder about a later pendulum-length question; it does not
record scientific evidence. For a first lesson centered on the shrinking-swing
question, use [Getting started](../scribblings/getting-started.scrbl). The supported
syntax is listed in the [first-slice contract](../spec/first-slice.md).
The [return-a-plan example](return-a-plan.rkt) shows a procedure returning a named
result to its caller. The [pendulum method](pendulum-method.rkt) uses that syntax to
print a timing plan; it does not perform a measurement.
The [verbose method example](verbose-method.rkt) calculates a period using the
equivalent word-based syntax. Compact and verbose forms can mix in one file.
The [assessor self-description](meta-assessor/README.md) is also runnable. It shows
the implemented structural interface check and its missing-part impact report.
The [protocol mapping example](protocol-mapping.rkt) uses direct `implement`
references to connect a pendulum stage and its uncertainty description to
nested protocol requirements.
The [conditional interface example](conditional-interface.rkt) uses the
existing `if`, `else if`, and `else` forms to require different fields for
different timing methods.
The [value-requirement example](value-requirements.rkt) mixes a numeric
condition, a required entry, and an exact-value requirement in one `must [...]`
group. Equality comparisons use `==`; assignments and defaults use `=`.
The [list-requirement example](list-requirements.rkt) uses `for each` inside
an interface to require a period and its uncertainty description in every
measurement of a list.
It also uses the reserved `.count` property to require at least three
measurements.
The [unknown-field example](unknown-fields.rkt) shows a required value that
rejects `unknown` and a planning interface that explicitly permits it with
`period = unknown`.
The [list-membership example](list-membership.rkt) uses `value in list`
in a condition and in an interface requirement for allowed timing methods.
The [field-presence example](field-presence.rkt) uses the same `in` operator
to check record fields and list items. A field containing `unknown` is present.
The [value-kind example](value-kinds.rkt) requires numeric measured periods
and explicitly permits unknown numeric values for planned periods.
The [nested-interface example](nested-interfaces.rkt) reuses `Timing` through
`must [timing is Timing]` and checks the same interface in an `if` condition.
The [optional-field example](optional-fields.rkt) uses `notes is text` and
`review is Review` outside `must` to check fields only when supplied.
The [interface-default example](interface-defaults.rkt) uses
`timing = unknown Timing` for a required field that starts as unknown and
later receives an object matching its interface.
The [unknown-equality example](unknown-equality.rkt) uses `period == unknown`
to require an explanation for a pending period and a positive value otherwise.

The prose examples are **provisional research and language sketches**, not
executable ScienceLogo programs. The [paired-stage syntax](../spec/stage-state.md)
used in the documentation is accepted by the reader as a method declaration,
but its body is not executed.
Their words and bracketed structure are candidates to test with scientists and learners.
They should inform the reader, validator, and run-record design before syntax is fixed.
The [draft semantic core](../spec/core.md) gives two of these sketches concrete run traces
and expected check outcomes.

Read each example in two ways: commands such as `measure`, `llm`, and `ask human` describe
activities; `must` states an obligation on the investigation or a named activity. A future
implementation needs to say exactly which obligations can be checked from the written
workflow, which need evidence from a run, and which need human judgment.
The [prompt and obligation design](../spec/prompts-and-obligations.md) proposes that `must`
be a checkable declaration, alongside named method components such as `prompt` and `agent`.
The [LLM variation design](../spec/llm-variation.md) expands the synthesis example with
multiple recorded suggestions and a stated review policy.

Each activity also needs a scientific context. Timing a pendulum must eventually identify
its length, swing count, elapsed time, and units; screening changes a paper's status;
fitting creates a model tied to particular data. The first sketch leaves some details
open for a beginner, while later sketches test how the language makes context explicit
before an AI activity uses it.

The synthesis example also sketches a named agent's working environment: its given material,
model, prompt, available tools, memory, and stopping rule. The run must retain what the agent
actually received and did. The modelling example uses a simpler LLM activity with explicit
context. This tests whether one language can describe both forms of AI use.

| Example | Main design question |
| --- | --- |
| [Pendulum period](pendulum-period.md) | Can a learner build from a readable timing plan to repeated measurements, uncertainty, and an evidence-backed comparison? |
| [Knowledge synthesis](knowledge-synthesis.md) | Can LLM-assisted screening and extraction remain traceable to sources and human decisions? |
| [Rainfall modelling](rainfall-modelling.md) | Can the same concepts cover data preparation, model comparison, LLM proposals, and held-out evaluation? |

The pendulum example starts without an LLM. Its later extension lets an LLM suggest an
interpretation while retaining the timings and human review. This progression matters:
ScienceLogo is a language for scientific workflows in the AI era, including investigations
that do not use AI.
