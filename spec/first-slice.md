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
its commands once, in order. `print value` displays text on a line, following Logo's
teaching convention. It is only a visible action for this slice, not a scientific
measurement or evidence record. Empty blocks are allowed. Whitespace is flexible;
commands may share a line. `;` ends a line comment, and
`#| ... |#` is a block comment that may nest.

A procedure may declare inputs after its name. A call supplies one value per input,
and may name the returned value with `as`. For example:

```text
investigate "What should we measure?" [
  do observation-plan "Bean plant" as plan
  print plan
  to observation-plan :plant [
    print :plant
    output "Measure its height each day."
  ]
]
```

This prints `Bean plant` and then `Measure its height each day.` The colon is used
only for a procedure input inside that procedure. A bare name such as `plan` refers
to a result named earlier with `as` in the current block or an enclosing block. A value
can currently be quoted text, a declared input, or a named result. `output` ends the
procedure call
and returns one value; a call with `as` requires an `output` in that procedure.
A nested `do [ ... ]` block can read results from its enclosing blocks. An `as` name
made inside that nested block stays there: enclosing and sibling blocks cannot read it.
A result name cannot duplicate an input or another result visible in its block, including
one from an enclosing block. Separate sibling blocks may use the same result name. A
procedure sees only its declared inputs, not the caller's result names.

The reader parses and validates the complete investigation before any command runs.
Definitions may appear after their calls, including a call inside another procedure.
Names are local to the investigation. Unknown calls, duplicate definitions, malformed
brackets, wrong input counts, unknown input or result names, calls requesting an absent
output, unsupported commands, and recursive procedure calls are rejected before
execution. This first slice has one investigation per file and accepts `to` definitions
only directly inside it. Recursion, scientific items and measurements, `repeat`, `stage`,
`must`, standards, agents, and `any order` are not implemented yet.

The [first runnable example](../examples/first-slice.rkt) and
[inputs and results example](../examples/inputs-and-results.rkt) can be run from an
installed package. The [plant-growth teaching example](../examples/plant-growth.md)
is still a design sketch; it has not been reduced to `print` commands.
