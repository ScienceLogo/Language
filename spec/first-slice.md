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

An investigation may import procedures before its `investigate` declaration:

```text
import "https://example.org/hello-world.git" at "v1.0.0" as hello
investigate "Try a library" [do hello.say-hello]
```

The URL is a placeholder. The real Git repository must have a `main` branch and a
root `library.rkt` with a `library "name" [ ... ]` declaration. It holds top-level
`to` definitions, `include "relative/path.rkt"` declarations, or library imports,
with no executable
commands. Included files hold top-level `to` and `include` declarations and can be
nested; paths are relative to the containing file and cannot escape the repository.
`at` names a tag or full commit ID on `main`, not a branch. Imported procedures use
`alias.procedure` in calls. Git must be available; the reader fetches and validates
the library before any commands run. See
the [hello-world library](libraries.md) for the complete file.

A library may import another library directly inside its `library` block. Its
procedures may call that dependency using the library's internal alias. The
importing investigation sees only the first library's own procedures; to call a
dependency directly, it imports that dependency separately. The reader records
each resolved revision and rejects import cycles.

## Describe and assess required parts

A separate `#lang sciencelogo` file can declare an interface for parts of a method:

```text
interface "Assessment process" [
  version "1"
  require collect
  require review
  require report
  affects collect review
  affects review report
]
```

An interface needs exactly one nonempty `version` and at least one `require`.
Required part names must be unique. Each `affects source target` names two required
parts; it says that a missing source can affect the target. This is a structural
dependency, not a measured uncertainty calculation.

An investigation can map those parts to implementation references:

```text
investigate "How will we review the data?" [
  implements "requirements/review.rkt" as review-process [
    provide collect by "methods/collection.md"
    provide review by "methods/review.md"
    provide report by "methods/report.md"
  ]
]
```

The path after `implements` is relative to the investigation file. A `provide`
reference is nonempty text naming where to inspect an implementation; the assessor
does not open or verify that reference. `implements` is a declaration and does not
run the named work. The assessor checks whether the interface file exists, reports
missing, unknown, or duplicate provisions, and follows `affects` links from missing
parts to downstream parts. It also reports duplicate interface aliases. An issue
causes the command to exit with status 1:

```text
racket -l sciencelogo/assessor -- path/to/investigation.rkt
```

The [self-description example](../examples/meta-assessor/README.md) is a complete
interface and investigation pair, with an incomplete method for testing impact
reports. Interface versions are displayed in assessments; this slice does not
compare versions or judge scientific adequacy.

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
procedure call and returns one value; a call with `as` requires an `output` in that
procedure.
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
execution. An investigation file has one investigation; a library file has one library
declaration. `to` definitions belong directly in either block or at the top of an
included file. Recursion, scientific items and measurements, `repeat`, `stage`, `must`,
standards beyond this structural interface check, agents, and `any order` are not
implemented yet.

The [first runnable example](../examples/first-slice.rkt) and
[inputs and results example](../examples/inputs-and-results.rkt) can be run from an
installed package. The [plant-growth teaching example](../examples/plant-growth.md)
is still a design sketch; it has not been reduced to `print` commands.
