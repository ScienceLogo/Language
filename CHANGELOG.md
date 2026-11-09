# Changelog

Version numbers have three parts, such as `0.2.1`. The first two, `0.2`,
name the language version: its syntax and the workflow model the reader
produces. A change to either starts a new language version. The third part
marks refinements, such as fixes and documentation, that change neither.
Workflows and tools written for language version `0.2` work with every `0.2`
release. Racket omits a third part of zero, so the first release of `0.2` is
written `0.2`.

**0.2 — 2026-11-09:**

- Local `include` paths start at the file that contains the include and no longer require Git or a Git repository. Git is used only for library imports.
- New `phase` declaration groups workflow-level stages and smaller phases, with an optional `about` description: `phase Name [Stage1 Stage2]`, or `phase Name contains Stage1 and Stage2` in verbose syntax. The reader checks that members exist, have one parent, follow file order, and cover a continuous stretch of stages.
- Breaking: a procedure's `about` now follows its name and inputs, before its opening bracket (`to name :input about "..." [ ... ]`). The old placement inside the brackets is an error that shows the new form.
- The workflow model records where each stage, phase, and procedure ends (`stage-model-end`, `phase-model-end`, `procedure-model-end`) and exposes phases through `workflow-model-phases`. A verbose `start stage` now starts at `start`.
- The library documentation describes the `@doc url:` comment marker that documentation tools read from `library.rkt`.
- The README, manual, and changelog explain version numbers: the first two parts name the language version, covering its syntax and workflow model, and the third marks refinements.

**0.1 — 2026-10-23:** Initial release of the language specification, compact and verbose syntax, Racket implementation, structural checks, translation, documentation and examples.
