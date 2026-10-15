# ScienceLogo

<img src="assets/logo.png" alt="ScienceLogo logo: a blue turtle with a flask-shaped shell" width="220">

**Human-centered scientific workflows in the AI era.**

**Mottos:**

- **Humans first in AI science.**
- Declarative, not decorative.

ScienceLogo is a Logo dialect for describing scientific workflows that people can
read and inspect. Its goal is to support human understanding, quality control,
and supervision when AI participates in science. A workflow should make clear
what information and assumptions an activity uses, where AI participates, and
who or what carries out the activity. We call that last role the **performer**;
paired stages can name a performer object as their default, and a call can name
another. AI may help plan, search,
select evidence, analyse data, interpret results, and write conclusions.
ScienceLogo should let people state the scientific criteria and evidence each
stage owes, specify what an agent may see and do, inspect what happened, and
decide when a person must review or intervene. Its procedures and nested, named
parts should remain understandable to a learner.

“Declarative, not decorative” means that rules about evidence, authority, and review become
checks on the specified procedure and its observed runs. They are part of the method even
when AI performs much of the work.

This repository is the working source for the language. It is set up as a single-collection
Racket package whose collection name is `sciencelogo`, with package metadata in `info.rkt`.
The first `#lang sciencelogo` reader and runner are available for a small set of
commands and Git-based library imports. The reader also checks paired stage
state declarations without executing their bodies. A structural assessor
checks declared calls, stage order, record fields, and workflow parts. To try
the language from a local checkout, install the package with
`raco pkg install --link .`, then follow the [Getting started manual page](scribblings/getting-started.scrbl).

## Read the language and its design

The [manual](scribblings/sciencelogo.scrbl) progresses from a small
investigation to values, procedures, stages and state, reusable definitions,
and assessment support. Its [Syntax page](scribblings/reference.scrbl) is a
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
