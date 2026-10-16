# ScienceLogo language boundary

ScienceLogo is a language for specifying scientific workflows. Its specification is
the authority for valid source and its meaning. Racket is the language of the
current reference implementation, not a requirement for ScienceLogo source or for
applications that use it.

## Compact and verbose syntax

ScienceLogo will have two fully equivalent ways to write the same language:
**compact** and **verbose** syntax. The forms accepted today are the compact
syntax. It is the reference form for specifying and checking language behavior.
The verbose syntax must express the same workflows and have the same meaning;
it must not introduce separate semantics or separate scientific checks.

A future translator will convert compact source to verbose source, verbose
source to compact source, and source that mixes the two into either form.
Verbose and mixed source will be converted to the compact form for the same
language checks. The verbose forms and translator are not yet specified or
implemented; the current reader accepts the compact forms only.

## What the specification defines

The specification defines how a ScienceLogo file is written and what its words
mean: which names are visible, what a call does, how values change, how branches
and loops work, and what a condition requires. It also defines the information
a reader gives to other programs about a written workflow. For example, that
information says which procedure a `do` command calls and which later command
uses its result. A reader written in any language must be able to provide the
same information. The file format for sharing it has not yet been selected.

This information must be sufficient for an application to find
the workflow parts and relationships that the source states. In particular, it
must keep the written method separate from any record of work that occurred and
from findings about that work. A declared activity does not show that it happened;
a declared condition does not show that it was satisfied. References to source
locations and resolved names must remain available so an application can explain
which part of a workflow it examined.

The specification defines what a condition says and which part of a workflow it
concerns. Applications decide how to evaluate scientific questions such as
protocol conformance, bias, and uncertainty, and how to report their findings.

## What software does

A **reader** recognizes ScienceLogo source, resolves its references, reports
invalid source, and produces the shared representation. The existing Racket reader
is one implementation of this responsibility. An application may instead use a
reader written in another language.

A **core interpreter** gives effect to ScienceLogo's own executable forms, such as
procedure calls, assignments, branches, and loops. It does not carry out the
scientific work described by a workflow merely because that work is named in the
source. The current Racket code includes an interpreter; its behavior must follow
the language specification.

**Tests** check an implementation against specified behavior. Shared conformance
cases should be usable by readers and interpreters written in different languages.
A **linter** gives optional advice about valid ScienceLogo source. Neither tests nor
lint define the language.

Applications such as protocol checkers, bias analyses, uncertainty analyses, and
publication generators are separate projects. They may use any programming
language. Their scientific rules and algorithms do not belong in the ScienceLogo
language package; the language supplies the syntax and representation they need.

## Current documents

- [First runnable slice](first-slice.md) and [Libraries](libraries.md) describe
  accepted runnable forms and file rules.
- [Paired stages and state locations](stage-state.md) describes accepted
  reader syntax that is checked as a method but not executed.
- [External scientific resources](resources.md) describes accepted resource
  declarations and data-flow syntax; the interpreter performs no external I/O.
- [Semantic core](core.md), [Design principles](design-principles.md),
  [Context sets](context.md), [Prompts and obligations](prompts-and-obligations.md),
  [LLM variation](llm-variation.md), and
  [Workflow publication support](workflow-documentation.md) develop meaning
  and future capabilities.

The [shared representation contract](representation.md) states what a reader
must preserve. Its portable schema remains to be defined. This page sets the
boundary without choosing a file format or adding new ScienceLogo syntax.
The [documentation map](README.md) gives each document's status and purpose.
