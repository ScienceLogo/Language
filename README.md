# ScienceLogo

<img src="assets/logo.png" alt="ScienceLogo logo: a blue flask with a turtle silhouette" width="220">

**Mottos:**

- **Humans first in AI science.**
- Declarative, not decorative.

ScienceLogo is an early-stage Logo dialect for scientific workflows in the AI era. Its central
goal is to support human understanding, quality control, and supervision when AI participates
in science. AI may help plan, search, select evidence, analyse data, interpret results, and
write conclusions. ScienceLogo should let people state the scientific criteria and evidence
each stage owes, specify what an agent may see and do, inspect what happened, and decide when
a person must review or intervene. Its procedures and nested, named parts should remain
understandable to a learner.

“Declarative, not decorative” means that rules about evidence, authority, and review become
checks on the specified procedure and its observed runs. They are part of the method even
when AI performs much of the work.

This repository is the working source for the language. It is set up as a single-collection
Racket package whose collection name is `sciencelogo`, with package metadata in `info.rkt`.
The first `#lang sciencelogo` reader and runner are available for a small set of
commands. The [first-slice contract](spec/first-slice.md) lists what runs today and what
remains design work. To try the example from a local checkout, install the package with
`raco pkg install --link .`, then run `racket examples/first-slice.rkt`.

## Read the draft

The [design examples](examples/README.md) are provisional workflows. The
[first runnable example](examples/first-slice.rkt) exercises the implemented subset.
Start with [plant growth](examples/plant-growth.md) for the small Logo-like form,
then [the plant-growth standard](examples/plant-growth-standard.md) for a reusable template
and nuanced assessment. [Knowledge synthesis](examples/knowledge-synthesis.md) introduces
AI participation and human review. [Rainfall modelling](examples/rainfall-modelling.md)
tests the same ideas in a different kind of investigation.

The [semantic core](spec/core.md) defines the intended meaning and works through valid and
invalid runs. The [prompt and obligation design](spec/prompts-and-obligations.md) develops
named LLM requests and `must` rules; the [LLM variation design](spec/llm-variation.md)
develops context selection, repeated attempts, replication, and control. The
[workflow publication support design](spec/workflow-documentation.md) defines the information
ScienceLogo should expose to external research publications, without prescribing a booklet
template.
The [release plan](RELEASE.md) tracks what remains before publication as a Racket package
and how GitHub releases will be archived on Zenodo.

## Documentation

End-user documentation is planned outside this repository. The local `docs/` directory is
ignored by Git. This repository keeps the README, examples, and design specifications needed
to develop the language; a Racket package does not require a `docs/` directory.

## License

ScienceLogo is released under the [MIT License](LICENSE).
Citation metadata is in [CITATION.cff](CITATION.cff).
