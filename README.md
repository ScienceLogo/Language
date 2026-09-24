# ScienceLogo

ScienceLogo is an early-stage Logo dialect for scientific workflows in the AI era. It aims to
make procedures, scientific obligations, and evidence from each run understandable and
inspectable, including when LLMs take part in the work.

This repository is the working source for the language. It is set up as a single-collection
Racket package whose collection name is `sciencelogo`, with package metadata in `info.rkt`.
The language reader, validator, and runtime have not been implemented yet, so
`#lang sciencelogo` is not available.

The [design examples](examples/README.md) are provisional workflows for testing the
language's readability and scientific meaning. They are not executable programs yet.
The draft [semantic core](spec/core.md) defines the meaning the first prototype should
preserve and works through valid and invalid runs for two examples.

## Documentation

The local `docs/` directory is ignored by Git for drafts while the documentation's eventual
home is decided. Racket packages do not require that directory. If ScienceLogo ships a Racket
manual, its Scribble source should be tracked in this repository and registered in `info.rkt`
so `raco setup` can build it when the package is installed. A separate website or broader
documentation project can still live elsewhere.
