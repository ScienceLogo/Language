# ScienceLogo

<img src="assets/logo.png" alt="ScienceLogo logo: a blue turtle with a flask-shaped shell" width="220">

**Human-centered scientific workflows in the AI era.**

**Mottos:**

- **Humans first in AI science.**
- Declarative, not decorative.

ScienceLogo is a Logo-inspired language for describing scientific workflows that people
can read and inspect. It aims to make research methods understandable, from
their overall purpose down to their steps, inputs, assumptions, and conditions.
When AI participates, the method should make its role visible so people can
question and supervise the work. The language should remain approachable to a
learner while supporting detailed scientific methods.

“Declarative, not decorative” means that stated conditions are part of the
method and can be checked, rather than serving only as explanatory prose.

This repository is the working source for the language. It is set up as a single-collection
Racket package whose collection name is `sciencelogo`, with package metadata in `info.rkt`.
The first `#lang sciencelogo` reader and runner are available for a small set of
commands and Git-based library imports. The reader also checks paired stage
state declarations without executing their bodies and represents data sources
and storage without accessing them. A structural assessor
checks declared calls, stage order, record fields, and workflow parts. To try
the language from a local checkout, install the package with
`raco pkg install --link .`, then follow the [Getting started manual page](scribblings/getting-started.scrbl).

## Read the language and its design

The [manual](scribblings/sciencelogo.scrbl) progresses from a small
investigation to values, procedures, stages and state,
[data sources and storage](scribblings/resources.scrbl),
reusable definitions, and assessment support. Its [Syntax page](scribblings/reference.scrbl) is a
lookup map of accepted forms. The [specification index](spec/README.md)
identifies what runs, what the reader only checks, and what remains design
work. Start with the [young Galileo pendulum case](examples/pendulum-period.md)
for the research progression; the [examples index](examples/README.md) labels
runnable programs and provisional sketches separately.

The [language boundary](spec/architecture.md) explains why scientific
applications such as protocol or bias assessment are separate from the
language package. The [shared representation contract](spec/representation.md)
describes what a reader should make available to those applications.

## License

ScienceLogo is released under the [MIT License](LICENSE).
Citation metadata is in [CITATION.cff](CITATION.cff).
