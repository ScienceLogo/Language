# First runnable ScienceLogo slice

**Status:** accepted runnable syntax and current structural checks. The
[manual](../scribblings/sciencelogo.scrbl) provides the learning path and form
index; this page records the implemented contract. Broader examples and
semantic designs remain proposals.

The reader also accepts the [paired stage state and location-based call forms](stage-state.md),
checks their declared structure, and retains them in the workflow model. The
current interpreter does not execute the body of a paired state stage; the
runnable forms described below keep their existing behavior.

## Source file, procedures, and stage headers

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
to make-plan [output "Time ten swings as the swing gets smaller."]
stage "Review"
print plan
```

The second stage can use `plan` because both stages are in the same workflow file.
Calling `do Review` would try to call a procedure named `Review`; it does not call
the stage.

## Files and libraries

Imports belong at the top of the workflow file, after an optional title and before method forms:

```text
workflow "Try a library"
import "file:///absolute/path/to/hello-world" at "v1.0.0" as hello
do hello.greeting as message print message
```

Replace the example URL with the absolute path to a local Git repository. It must
have a `main` branch and a
root `library.rkt` with a `library "name" [ ... ]` declaration. It holds top-level
`to` definitions, record `interface` declarations, `include "relative/path.rkt"`
declarations, or library imports,
with no executable
commands. Included library files hold top-level `to`, record `interface`, and
`include` declarations and can be
nested; paths are relative to the containing file and cannot escape the repository.
`at` names a tag or full commit ID on `main`, not a branch. Imported procedures use
`alias.procedure` in calls. Imported record interfaces use `alias.Interface` in
construction, `extends`, and `must ... implement` checks. Imported stage names
carry the library alias in the
method model, so separate libraries may reuse a stage label. Git must be available;
the reader fetches and validates the library before any commands run. See
the [hello-world library](libraries.md) for the complete file.

A library may import another library directly inside its `library` block. Its
procedures may call that dependency using the library's internal alias. The
importing investigation sees only the first library's own procedures; to call a
dependency directly, it imports that dependency separately. The same rule
applies to record interfaces. The reader records
each resolved revision and rejects import cycles.

A workflow can also use `include "relative/path.rkt"` at top level. An included
workflow file can contain top-level commands, stages, procedures, record
interfaces, `must` declarations, and more includes. It has no `workflow` title
or `import`: the entry file supplies the one title and its imports. Each include
path is resolved relative to the file containing it. For example, an include
in `methods/measure.rkt` can load `../shared/period.rkt`. The resulting path
must remain inside the same Git repository. Included files begin with
`#lang sciencelogo`. The reader rejects missing files, duplicate includes,
and cycles, and validates the assembled workflow before running it.

## Declared structural checks

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

An interface may have one nonempty `version`, or omit it. A workflow-part
interface needs at least one `require`.
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

`must do name` belongs directly in an investigation. The assessor checks the
written method's paths, including calls through other procedures. A call that
every established path reaches is **satisfied**. A definition alone, a call
inside an unused procedure, or one confined to `if false`, `while false`,
`repeat 0`, or an empty `for each` collection is **violated**. If the call
depends on a condition or count that cannot be established from literal values,
the result is **undetermined**. An unresolved condition also prevents a
guaranteed result. The reader rejects an unknown procedure name. This check
does not prove that a run took place or that the procedure did adequate
scientific work. The declaration does not call the procedure.

This first path check resolves literal booleans and comparisons, fixed counts,
and whether literal lists or valid literal ranges are empty. It follows nested
blocks, procedure calls, and early `output`. Named values, procedure inputs,
and procedure results remain unknown to this check, even when another line
sets a name to a literal. For a loop known to run, the checker analyzes its
first iteration for a required call; it does not infer later state changes.
Undetermined findings remain visible in the assessor report and cause a
nonzero command exit status.

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
The first `set` of a name produces a value slot; later `set` commands record
`updates` links to that slot. A later read records possible dependencies on
both its creation and earlier update sites.
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
duplicate, or mismatched link. Control activities retain their condition or
collection expression so the assessor can distinguish reachable, conditional,
and impossible calls. `must do` conditions are retained in the method model
and reported as satisfied, violated, or undetermined by the assessor.

## Values, inputs, and results

A procedure can return a value, which its caller may name with `as`. For example:

```text
workflow "What is our observation plan?"
do observation-plan as plan
print plan
to observation-plan [output "Time ten swings as the swing gets smaller."]
```

The procedure returns the plan; the caller prints it. A procedure may also declare
inputs after its name. For instance, `to echo :text [output :text]` returns the one
value supplied by `do echo "Pendulum P1" as subject`. The colon is used only for an
input inside that procedure. A bare name such as `plan` or `subject` refers to a
value named earlier with `as` or `set` in the current block or an enclosing block. A value
can be quoted text, an exact decimal or integer, `true`, `false`, `unknown`,
a list, a numeric range, a declared input, or a named value. Values can be
combined into arithmetic and Boolean expressions. Write spaces around
operators; use parentheses to group expressions. `output` ends
the procedure call and returns one value; a call with `as` requires an `output`
in that procedure.
A nested `do [ ... ]` block can read results from its enclosing blocks. An `as` name
made inside that nested block stays there: enclosing and sibling blocks cannot read it.
A result name cannot duplicate an input or another result visible in its block, including
one from an enclosing block. Separate sibling blocks may use the same result name. A
procedure sees only its declared inputs, not the caller's result names.

## Records and interfaces

Brackets beginning with `name = value` create a value with named fields:

```text
set trial to [
  temperature = 0.8
  prompt = "tell me the capital of Peru"
]
print temperature of trial
```

The field names are labels, and the values can be quoted text, exact numbers,
expressions, lists, or other values with named fields. Field names are unique.
`temperature of trial` reads a field and raises an error if `trial` has no
named fields or lacks `temperature`. Field order does not affect equality.
The brackets still denote an ordinary list when they do not begin with
`name = value`: `[x y]` contains two named values, and `[[1 2] [3 4]]`
contains two rows. Parenthesize a comparison meant to be a list item, as in
`[(x = y)]`. The language supplies this generic structure; libraries can
define what particular fields mean.

`record but [field = value ...]` makes a new named-field value from `record`.
Fields in the brackets replace existing fields or add new ones; other fields
are retained. The original value is unchanged. The value before `but` must
have named fields, and the brackets after `but` must contain named fields.
For example:

```text
set human to [species = "human" gender = "unspecified"]
set john to human but [gender = "male"]
set earlier to john
set john to john but [height = 193]
```

`earlier` still has the value it received before the last assignment, while
`john` now also has `height`. A plain `set another to john` assigns
the same immutable value without needing `but`. Quoted text such as `"male"`
is literal; an unquoted name refers to a value defined earlier. A record
interface may supply defaults when constructing a new record. It also states
structural obligations that can be checked independently with `must`.

A record interface may be declared directly in a workflow:

```text
interface "Timing" [duration unit = "seconds"]
set trial to Timing but [duration = 2]
must trial implement Timing
```

`duration` is required; `unit` defaults to `"seconds"` and can be overridden
with `but [unit = "minutes"]`. Every field named in the interface must be
present in the resulting record, but additional fields are allowed. There is
no separate optional-field category. A record made without the constructor
can also satisfy the interface. `unknown` is an explicit value and counts as
present; omission does not. A standalone interface file can be checked with
`must trial implement "relative/path.rkt"`. The assessor checks field
presence from direct `set` and `but` statements. When the record depends on
a procedure result or control flow it reports undetermined. Both local and
standalone interfaces may omit `version`; assessments retain the source
revision hash.

Record interfaces can inherit and combine other record interfaces:

```text
interface "Timed-observation" [
  extends Timing
  extends Location
  observation
  unit = "minutes"
]
interface "Timing" [duration unit = "seconds"]
interface "Location" [place]
```

One `extends` inherits one parent; repeated `extends` combines their fields.
References can point to later declarations in the same workflow, declarations
in included files, or imported library interfaces named `alias.Interface`. Identical
inherited declarations merge. The child's own field declaration replaces any
inherited declaration of that field, including a default; this also resolves
conflicting inherited declarations. Without an explicit child declaration,
different inherited requirements or defaults for the same field are a read
error. Unknown parents, duplicate parents, and extension cycles are errors.
Constructing from the combined interface applies the resolved defaults and
requires all resolved bare fields. A `must` check uses those same resolved
fields. `but []` can construct an interface when no bare field remains to be
supplied. Standalone interface files cannot use local `extends` references.

## Lists, ranges, loops, and conditions

`set name to value` creates a local name or updates a visible name previously
created with `set`. This separates a range's definition from its uses. For
instance, the same range can drive two parameter sweeps:

```text
workflow "Which pendulum lengths should we compare?"
set lengths to range 0.25 to 1.00 step 0.25
for each length in lengths [print length]
for each length in lengths [
  if length >= 0.75 [print "longer trial"]
]
```

The range is an ordered sequence of exact numbers. It includes the end only
when a whole number of steps lands on it. Its bounds and step can also be
procedure inputs or previously named values. A zero step or a step moving away
from the end is an error. `[0.25 0.50 0.75]` is a list literal; lists can contain
other values or lists. A `for each` collection must evaluate to a list. Nested
`for each` blocks express combinations of parameters. These forms describe and
run the iteration of the written method; `print` still only displays text.

List positions start at 1. `item 1 of lengths` reads the first value;
`item 0 of lengths` is an error. An index can be a named value or expression,
as in `item position of lengths` or `item 1 + 1 of lengths`. It must be an
exact positive integer within the list. A matrix represented as a list of
rows uses the same rule at each level: `item 2 of item 1 of grid` reads the
second value of the first row. `item` needs a list; named fields use
`field of value`. A numeric range may still start at zero because its values
are not list positions.

`repeat 3 [ ... ]` runs a block a fixed number of times; its count must be a
nonnegative integer. `while condition [ ... ]` tests before each iteration.
`repeat [ ... ] until condition` runs at least once and tests afterward. The
post-test condition can use a value named inside the block for that iteration.
Each iteration has a fresh local scope, so new names do not leak into the
next iteration or the surrounding block. A `set` inside that block can update
a visible `set` name from an enclosing block. Procedure inputs, `as` results,
and `for each` iteration names cannot be updated this way. This makes a
terminating condition possible, for example:

```text
set continue to true
while continue [
  print "One planned pass"
  set continue to false
]
```

A changing count can be written `set attempts to attempts + 1`. Arithmetic
supports `+`, `-`, `*`, and `/` on exact numbers. A finite decimal quotient
is displayed as a decimal; another rational quotient is displayed as a
fraction, such as `1/3`. Division by zero is an error. Expressions also work
in range bounds and steps, repeat counts, lists, outputs, and procedure
arguments. For example, `do add 1 + 2 (3 * 4) as total` supplies two inputs.

`if condition [ ... ] else if another-condition [ ... ] else [ ... ]` runs the
first branch whose condition is true, or the optional `else` branch. Conditions
can combine Boolean values and comparisons with `=`, `!=`, `<`, `<=`, `>`, or
`>=`. Ordered comparisons require numbers. `not` reverses a Boolean value,
`and` needs both sides true, `or` needs either side true, and `xor` needs
exactly one side true. Precedence from strongest to weakest is parentheses,
unary `-`, `*` and `/`, `+` and `-`, comparisons, `not`, `and`, `xor`, then
`or`. Field access with `of` binds more tightly than `but`, which binds more
tightly than unary `-` and arithmetic. Operators at one level associate left to
right. Comparisons cannot be
chained; combine them with `and`. `unknown` explicitly represents an
undetermined value. `false and unknown` resolves to `false`, and `true or
unknown` resolves to `true`; other uses of `unknown` remain undetermined. An
undetermined or nonboolean condition raises an error rather than selecting
`else`. A branch
has its own local scope. The runner stops `while` and `repeat ... until` loops
after 10,000 iterations with a nontermination error. The static method model
records loop bodies and alternative branches, but does not claim that they ran
or that a particular condition was resolved.

## Reader validation and current limits

The reader parses and validates the complete investigation before any command runs.
Definitions may appear after their calls, including a call inside another procedure.
Names are local to the investigation. Unknown calls, duplicate definitions, malformed
brackets, wrong input counts, unknown input or result names, calls requesting an absent
output, unsupported commands, and recursive procedure calls are rejected before
execution. A workflow file has at most one optional title line; a library file has one library
declaration. `to` definitions belong directly in the workflow file or library block, or at the top of an
included file. Recursion, domain-specific records and measurements,
other `must` rules, standards beyond these structural checks, agents, and `any order` are not
implemented yet.

The [first runnable example](../examples/first-slice.rkt),
[return-a-plan example](../examples/return-a-plan.rkt), and
[pendulum planning example](../examples/pendulum-method.rkt), along with the
[parameter sweep example](../examples/parameter-sweep.rkt), can be run from an
installed package. The [pendulum period design case](../examples/pendulum-period.md)
describes measurements and run checks beyond the current runnable slice.
