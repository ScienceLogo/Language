# ScienceLogo language boundary

ScienceLogo is a language for specifying scientific workflows. Its specification is
the authority for valid source and its meaning. Racket is the language of the
reference implementation, not a requirement for ScienceLogo source or for
applications that use it.

## Compact and verbose syntax

ScienceLogo has two equivalent ways to write the same language:
**compact** and **verbose** syntax. Compact syntax is the reference form for
specifying and checking language behavior.
The verbose syntax expresses the same workflows with the same meaning;
both spellings use the same semantics and scientific boundaries.

The normalizer converts verbose and mixed source to compact source before
parsing, name resolution, and language checks. The reference reader uses this
sequence for workflows, included files, and imported libraries. SDKs can use
the same boundary and implement the compact parser and checks once.
The [normalization API](../normalize.rkt) returns compact text and original
source locations while retaining comments and explicit groups.
The [verbose syntax specification](verbose-syntax.md) defines the equivalent
spellings and preservation requirements. The API converts source to compact
form; it does not generate verbose source from compact source.

## What the specification defines

The specification defines how a ScienceLogo file is written and what its words
mean: which names are visible, what a call does, how values change, how branches
and loops work, and what a condition requires. It also defines the information
a reader gives to other programs about a written workflow. For example, that
information says which procedure a `do` command calls and which later command
uses its result. A reader written in any language must be able to provide the
same information. This contract defines the information to preserve, not a
file format for exchanging it. The reference API exposes Racket values and
does not provide a language-neutral export format.

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
invalid source, and produces the shared representation. The Racket reader
is one implementation of this responsibility. An application may instead use a
reader written in another language.

A **core interpreter** gives effect to ScienceLogo's own executable forms, such as
procedure calls, assignments, branches, and loops. It does not carry out the
scientific work described by a workflow merely because that work is named in the
source. The Racket code includes an interpreter; its behavior must follow
the language specification.

**Tests** check an implementation against specified behavior. Shared conformance
cases should be usable by readers and interpreters written in different languages.
A **linter** gives optional advice about valid ScienceLogo source. Neither tests nor
lint define the language.

Applications such as protocol checkers, bias analyses, uncertainty analyses, and
publication generators are separate projects. They may use any programming
language. Their scientific rules and algorithms do not belong in the ScienceLogo
language package; the language supplies the syntax and representation they need.

## Reference documents

The [specification guide](README.md#language-specification) groups the grammar,
language rules, and individual feature contracts. The
[shared representation contract](representation.md) defines what readers
must preserve. The [manual](../scribblings/sciencelogo.scrbl) provides the
learning path and syntax lookup.

[Design rationale](README.md#design-rationale) and
[earlier design notes](README.md#earlier-design-notes) are separate from the
language rules. Their exploratory examples do not add source forms, reader
requirements, or implementation commitments.
