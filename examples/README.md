# ScienceLogo examples

## Runnable examples

The [procedure-call example](first-slice.rkt) is a small `#lang sciencelogo` program for
checking `to`, `do`, forward references, ordered blocks, and Logo's `print` command.
It prints a method reminder about a later pendulum-length question; it does not
record scientific evidence. For a first lesson centered on the shrinking-swing
question, use [Getting started](../scribblings/getting-started.scrbl). The supported
syntax is defined in [Language rules and reference behavior](../spec/first-slice.md).
The [return-a-plan example](return-a-plan.rkt) shows a procedure returning a named
result to its caller. The [pendulum method](pendulum-method.rkt) uses that syntax to
print a timing plan; it does not perform a measurement.
The [verbose method example](verbose-method.rkt) calculates a period using the
equivalent word-based syntax. Compact and verbose forms can mix in one file.
The [assessor self-description](meta-assessor/README.md) is also runnable. It shows
the structural interface check and its missing-part impact report.
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

## Research progression

The [young Galileo pendulum case](pendulum-period.md) explains how an
investigation can develop from a timing question to repeated observations,
uncertainty descriptions, and conclusions related to hypotheses. It is a
prose account of research, not a program that performs measurements.
The [paired-stage syntax](../spec/stage-state.md) represents such a method
with entry and exit state and location-based calls; the interpreter does
not execute paired-stage bodies.

## Earlier exploratory sketches

These two sketches retain examples from earlier design discussions. Their
pseudo-code is not ScienceLogo syntax or a roadmap for language features.
Use the runnable examples and [manual](../scribblings/sciencelogo.scrbl)
for valid source.

| Sketch | Subject |
| --- | --- |
| [Knowledge synthesis](knowledge-synthesis.md) | LLM-assisted screening and extraction, sources, and human decisions. |
| [Rainfall modelling](rainfall-modelling.md) | Data preparation, model comparison, LLM suggestions, and evaluation. |

Related [earlier design notes](../spec/README.md#earlier-design-notes)
retain the method/run, prompt, and LLM-variation explorations separately
from the language specification.
