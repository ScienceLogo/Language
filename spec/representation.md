# Shared representation of a written workflow

**Status:** design contract for a portable representation. The current Racket
reader produces an inspectable Racket workflow model, including paired-stage
state and call locations. A language-neutral exchange format and its versioning
rules remain to be specified.
This contract covers a **written method**. A record of what happened and an
assessment of that record are separate things.

## Purpose

A portable representation should let a program inspect ScienceLogo source
without using Racket. It must preserve the meaning of the
source, including control flow and references; it is not merely a list of words
or a flat list of stages. A program may use it to explain a method or check a
declared condition.

The representation makes no claim that a described action occurred. It does not
contain a scientific assessment simply because the source declares a `must` rule
or an interface implementation.

For example, consider this short method:

```text
#lang sciencelogo
workflow "Review a timing plan"
stage "Prepare"
do make-plan as plan
to make-plan [output "Time ten swings as the swing gets smaller."]
stage "Review"
print plan
```

The reader identifies two stage labels, one procedure definition, one call of
that procedure, the result named `plan`, and a later command that uses `plan`.
It retains the call before the later use even though the procedure definition
appears after the call in the source. It does not report that anyone timed a
pendulum.

## Information to preserve

- **Identity and origin.** Identify the language version, the source workflow
  and its revision, each included file, and each resolved library revision.
  Identify the source location of each declaration and command. Element
  identifiers must be unambiguous within the identified method revision;
  their spelling and stability across revisions remain to be defined.
- **Definitions and structure.** Preserve the workflow title, procedure
  definitions and inputs, stage headers and paired-stage entry and exit state,
  record interfaces, imports, and includes. A stage remains a label and
  checkpoint, not a procedure call or variable scope. A procedure definition
  does not count as a call.
- **Commands and values.** Preserve each command, its arguments and result
  name where present, nested blocks, branches, loops, and the expressions
  needed to understand them. Lists, records, ranges, quoted text, and the
  explicit value `unknown` retain their distinct forms. An absent field is
  different from a field whose value is `unknown`.
- **References and relationships.** Preserve the resolved target of each
  procedure call, imported name, variable read, assignment, and interface
  reference. For a paired-stage call, preserve each named input location and
  its return location. Preserve containment, required order, result production and use,
  and the dependencies that follow from them. The representation must not
  invent an order between activities that the method leaves unordered.
- **Conditions.** Preserve each declared requirement or guard, its target,
  scope, and the point at which it is relevant. The representation records
  what is required, without recording it as satisfied. An assessor's finding
  belongs to a separate assessment record.

Inputs, results, and other values appear through the commands and references
that use them. ScienceLogo does not impose a generic `Item` type or a catalogue
of scientific objects. Libraries can define records and interfaces for their
own domains.

## Checks on a reader

Two conforming readers must agree on the parts and relationships that valid
source states, even if their internal data structures differ. At minimum, a
reader must reject unresolved or ambiguous names, invalid scope use, and
malformed syntax according to the language specification. It must preserve a
branch or loop as such instead of reporting every command inside it as an
unconditional action. A source map must let a tool point back to the text that
gave rise to a represented part or relationship.

The [first runnable slice](first-slice.md) supplies currently implemented
examples. The [semantic core](core.md) describes wider goals. A portable schema,
its compatibility rules, and conformance cases will make this contract
testable by readers written in different languages.
