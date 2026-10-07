# First runnable ScienceLogo slice

This is the syntax implemented by `#lang sciencelogo` today. The broader examples and
semantic designs remain proposals.

```text
investigate "research question" [
  do procedure-name
  do [
    print "text"
    do another-procedure
  ]
  to procedure-name [print "text"]
  to another-procedure [print "more text"]
]
```

An investigation contains `to` definitions and executable commands. `to name [ ... ]`
defines a procedure without running it. `do name` calls one procedure; `do [ ... ]` runs
its commands once, in order. `print "text"` displays text on a line, following Logo's
teaching convention. It is only a visible action for this slice, not a scientific
measurement or evidence record. Empty blocks are allowed. Whitespace is flexible;
commands have fixed forms, so they may share a line. `;` ends a line comment, and
`#| ... |#` is a block comment that may nest.

The reader parses and validates the complete investigation before any command runs.
Definitions may appear after their calls, including a call inside another procedure.
Names are local to the investigation. Unknown calls, duplicate definitions, malformed
brackets, unsupported commands, and recursive procedure calls are rejected before
execution. This first slice has one investigation per file and accepts `to` definitions
only directly inside it. Recursion, inputs and results, `repeat`, `stage`, `must`,
standards, agents, and `any order` are not implemented yet.

The [runnable example](../examples/first-slice.rkt) can be run from an installed package
with `racket examples/first-slice.rkt`. The [plant-growth teaching example](../examples/plant-growth.md)
is still a design sketch; it has not been reduced to `print` commands.
