# First runnable ScienceLogo slice

This is the syntax implemented by `#lang sciencelogo` today. The broader examples and
semantic designs remain proposals.

```text
#lang sciencelogo
workflow "research question"
do procedure-name
do [
  print "text"
  do another-procedure
]
to procedure-name [print "text"]
to another-procedure [print "more text"]
```

A workflow is the whole file. An optional `workflow "title"` line names it for
references and reports; the title is not a bracketed scope and can appear only once
as the first form, before imports or method forms. A library or interface file
cannot use this title. A workflow file without a title remains a workflow and
can still be assessed by its file identity.
The file contains `to` definitions and executable commands. `to name [ ... ]`
defines a procedure without running it. `do name` calls one procedure; `do [ ... ]` runs
its commands once, in order. `print value` displays text on a line, following Logo's
teaching convention. It is only a visible action for this slice, not a scientific
measurement or evidence record. Empty blocks are allowed. Whitespace is flexible;
commands may share a line. `;` ends a line comment, and
`#| ... |#` is a block comment that may nest.

`stage "name"` labels the following executable commands in the same block until the
next stage header or the block's end. A stage is a section and checkpoint, not an
activity or callable procedure. It does not change result visibility or create a new
scope. A `to` definition placed between stage headers remains available throughout
the workflow. Stage names must be unique across the workflow and its procedures.
For example:

```text
workflow "Review a timing plan"
stage "Prepare"
do make-plan as plan
to make-plan [output "Time ten swings at each length."]
stage "Review"
print plan
```

The second stage can use `plan` because both stages are in the same workflow file.
Calling `do Review` would try to call a procedure named `Review`; it does not call
the stage.

Imports belong at the top of the workflow file, after an optional title and before method forms:

```text
workflow "Try a library"
import "file:///absolute/path/to/hello-world" at "v1.0.0" as hello
do hello.greeting as message print message
```

Replace the example URL with the absolute path to a local Git repository. It must
have a `main` branch and a
root `library.rkt` with a `library "name" [ ... ]` declaration. It holds top-level
`to` definitions, `include "relative/path.rkt"` declarations, or library imports,
with no executable
commands. Included files hold top-level `to` and `include` declarations and can be
nested; paths are relative to the containing file and cannot escape the repository.
`at` names a tag or full commit ID on `main`, not a branch. Imported procedures use
`alias.procedure` in calls. Imported stage names carry the library alias in the
method model, so separate libraries may reuse a stage label. Git must be available;
the reader fetches and validates the library before any commands run. See
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

An investigation can also state a directly checkable obligation:

```text
workflow "How will we compare pendulum periods?"
must do compare-periods
do prepare-comparison
to prepare-comparison [do compare-periods]
to compare-periods []
```

`must do name` belongs directly in an investigation. The assessor checks that the
method has a call to `name` reachable from the investigation body, including calls
through other procedures. A definition alone, or a call inside an unused procedure,
does not satisfy it. The reader rejects an unknown procedure name. This is a check
of the written method; it does not prove that a run took place or that the procedure
did adequate scientific work. The declaration does not call the procedure.

The workflow can require an ordered set of top-level stage headers:

```text
workflow "How will we time a pendulum?"
must stages in order ["Prepare" "Time" "Review"]
stage "Prepare"
stage "Time"
stage "Review"
```

The list needs at least two distinct quoted names. The assessor checks that each
name matches exactly one top-level stage header and that those headers occur in the
listed order. Unlisted stages may appear between them. A missing, repeated, or
out-of-order named stage produces a finding. A stage inside a procedure or `do [ ... ]`
block does not match a top-level requirement. This checks the written method's
structure, not whether the stages ran or their work was adequate.

An investigation can map those parts to implementation references:

```text
workflow "How will we review the data?"
implements "requirements/review.rkt" as review-process [
  provide collect by "methods/collection.md"
  provide review by "methods/review.md"
  provide report by "methods/report.md"
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

## Inspect the specified method

The Racket module `sciencelogo/workflow-model` provides `read-workflow-model` for an
investigation file and `read-interface-model` for an interface file. The first returns
separate records for the workflow, stages, procedures, activities, named input and result slots,
imports, interface claims, and typed relations. Method elements carry source locations;
the workflow revision reflects its source and resolved library definitions. Direct
imports record their resolved Git commits; imported procedures retain source references.
A `do` call has an `invokes` relation to its procedure. Sequential
commands have `precedes` relations; a named result has `produces` and `uses` relations.
For example, `do collect as observations` followed by `do analyze observations`
expresses that the analysis depends on the collection through the named result. The
reader checks the result's scope, and the model records this `depends-on` relation.
The relation is part of the meaning of the existing syntax; it needs no separate
declaration. Stage membership is also recorded from the stage headers, while order
continues across stage boundaries in the same executable block.
The model is a description of the written method, not an observed run or a set of
scientific measurements.

The assessor's `assess-workflow` accepts that model. `assess-file` reads a file and
calls it. In addition to the command-line report above, the returned assessment has
structured condition checks and findings. An interface's `require` line is represented
as a condition whose current evidence is a matching `provide` declaration. A satisfied
check therefore means that the declaration is present; it does not establish that the
referenced work exists, happened, or is scientifically sound. An `affects` link reports
a possible downstream impact as undetermined. The assessor also rejects malformed
typed relations in a constructed method model. The parser validates names and call
references before a model is built. Every stage, activity, and named item must have exactly
one containment link to its recorded parent; the assessor reports a missing,
duplicate, or mismatched link. `must do` conditions are also retained in the method
model and reported as satisfied or violated by the assessor.

A procedure can return a value, which its caller may name with `as`. For example:

```text
workflow "What is our observation plan?"
do observation-plan as plan
print plan
to observation-plan [output "Time ten swings at each length."]
```

The procedure returns the plan; the caller prints it. A procedure may also declare
inputs after its name. For instance, `to echo :text [output :text]` returns the one
value supplied by `do echo "Pendulum P1" as subject`. The colon is used only for an
input inside that procedure. A bare name such as `plan` or `subject` refers to a
result named earlier with `as` in the current block or an enclosing block. A value
can currently be quoted text, a declared input, or a named result. `output` ends
the procedure call and returns one value; a call with `as` requires an `output`
in that procedure.
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
execution. A workflow file has at most one optional title line; a library file has one library
declaration. `to` definitions belong directly in the workflow file or library block, or at the top of an
included file. Recursion, scientific items and measurements, `repeat`,
other `must` rules, standards beyond these structural checks, agents, and `any order` are not
implemented yet.

The [first runnable example](../examples/first-slice.rkt),
[return-a-plan example](../examples/return-a-plan.rkt), and
[pendulum planning example](../examples/pendulum-method.rkt) can be run from an
installed package. The [pendulum period design case](../examples/pendulum-period.md)
describes measurements and run checks beyond the current runnable slice.
