# ScienceLogo

<img src="assets/logo.png" alt="ScienceLogo logo: a blue turtle with a flask-shaped shell" width="220">

**Human-centered scientific workflows in the AI era.**

ScienceLogo is a Logo-inspired language for describing scientific workflows that people
can read and inspect. It aims to make research methods understandable, from
their overall purpose down to their steps, inputs, assumptions, and conditions.
When AI participates, the method should make its role visible so people can
question and supervise the work. The language should remain approachable to a
learner while supporting detailed scientific methods.

“Declarative, not decorative” means that stated conditions are part of the
method and can be checked, rather than serving only as explanatory prose.

This repository contains the language specification, manual, and Racket reference
implementation. ScienceLogo has equivalent compact and verbose syntax, which
can be mixed in the same source file. The reference implementation provides
the `#lang sciencelogo` reader, a core interpreter, and a structural assessor.
To try the language from a local checkout, install the package with
`raco pkg install --link .`, then follow the [Getting started manual page](scribblings/getting-started.scrbl).

## Read the language

The [manual](scribblings/sciencelogo.scrbl) progresses from a small
investigation to values, procedures, stages and state,
[data sources and storage](scribblings/resources.scrbl),
reusable definitions, and assessment support. Its [Syntax page](scribblings/reference.scrbl) is a
lookup map of language forms. The [specification index](spec/README.md)
groups the language rules separately from design rationale and earlier notes.
The [examples index](examples/README.md) provides runnable programs and a
[young Galileo pendulum case](examples/pendulum-period.md) showing how an
investigation can develop from a question to observations and conclusions.

The [language boundary](spec/architecture.md) explains why scientific
applications such as protocol or bias assessment are separate from the
language package. The reader records paired stages and external data flow
without performing the described scientific work or data transfers. The
structural assessor checks declared calls, stage order, workflow parts, and
record requirements. The [shared representation contract](spec/representation.md)
describes the method information available to independent applications.

## License

ScienceLogo is released under the [MIT License](LICENSE).
Citation metadata is in [CITATION.cff](CITATION.cff).
