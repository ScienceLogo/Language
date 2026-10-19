# Propositions

**Status:** accepted compact syntax. The reader preserves named propositions
and later changes in the workflow model. The interpreter checks their shape
and applies runnable changes. Scientific judgment belongs to applications
using the language.

## Named propositions

A proposition is a named hypothesis, assumption, or conclusion. Declare one
directly in a workflow:

```text
hypothesis shorter-swing [text = "A shorter swing has a shorter period"]
assumption hand-timing [text = "Hand timing is comparable across trials"]
conclusion regular-period [text = "The observed period was nearly constant"]
```

The root collections are `hypotheses`, `assumptions`, and `conclusions`.
Each proposition has quoted `text` and a name unique among propositions of
its type at that location. Names under different parents have different full
paths. A declaration can appear after a command that refers to it.

An independent conclusion is reached without an explicit hypothesis link.
It belongs at the root, as `regular-period` does above. It can still be based
on evidence. The language does not require a conclusion for every hypothesis
or require every conclusion to answer a hypothesis.

## Nesting and references

`+=` adds one named proposition beneath another. The child's type determines
its collection:

```text
hypotheses.shorter-swing += conclusion not-supported [
  text = "The measurements did not support a shorter period"
]
```

This conclusion answers `shorter-swing` because it is inside that hypothesis.
The explicit paths identify both statements:

```text
conclusions.regular-period
hypotheses.shorter-swing.conclusions.not-supported
```

Use `.text` to read their wording. A proposition can have children of any of
the three types. The plural collection name works at every level; for example,
`hypotheses.shorter-swing.assumptions.timer-rate` refers to an assumption
inside that hypothesis. Nesting records an explicit relationship. It does
not establish whether the relationship is scientifically sound.

Nested propositions may also be written when the parent is declared:

```text
hypothesis shorter-swing [
  text = "A shorter swing has a shorter period"
  conclusions = [not-supported = [text = "Measurements did not support it"]]
]
```

Each collection is a named record. Omitted collections are empty. `[]` is
accepted for an empty collection.

## Adding and updating

`+=` adds a child. It never replaces one. Adding the same type and name at
the same location a second time is an error, including when the name and
type repeat those of the parent:

```text
hypotheses.shorter-swing += conclusion not-supported [text = "First finding"]
hypotheses.shorter-swing += conclusion not-supported [text = "Second finding"] ; error
```

The reader rejects repeated additions to the same written path in the
workflow's top-level command sequence. The interpreter also rejects a
duplicate when an addition executes, including one already present in a
declaration.

Use `=` to update an existing field:

```text
hypotheses.shorter-swing.conclusions.not-supported.text = "Revised finding"
```

`=` cannot create a new named proposition inside a collection, or change a
proposition's type or name. A new independent conclusion may be declared at
the root or added there with
`conclusions += conclusion regular-period [text = "..."]`.
The ordinary `+=` rules for numbers, lists, and other records remain in
effect outside propositions.

## Workflow model and stage context

The workflow model preserves each root declaration, its type, its fields,
and later update commands with source locations. A paired stage's
`information` set can carry a proposition, for example
`information = [claim = hypotheses.shorter-swing]`. Its location-based calls
can describe a returned revision of that proposition. A paired stage is a
declaration and is not executed; direct `+=` changes to state in its body
are not accepted. The reader checks declaration syntax and repeated top-level
additions. The interpreter checks paths and other duplicates when runnable
commands execute. The structural assessor
does not decide whether a hypothesis is answered or whether a conclusion is
justified.
