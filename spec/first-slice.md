# First runnable ScienceLogo slice

**Status:** accepted runnable syntax and current structural checks. The
[manual](../scribblings/sciencelogo.scrbl) provides the learning path and form
index; this page records the implemented contract. Broader examples and
semantic designs remain proposals.

The reader also accepts the [paired stage state and location-based call forms](stage-state.md),
checks their declared structure, and retains them in the workflow model. The
current interpreter does not execute the body of a paired state stage; the
runnable forms described below keep their existing behavior.
The [resource form](resources.md) names data sources and storage outside the
workflow. Its assignments are represented in the model; the interpreter does
not transfer data to or from them.
The [proposition forms](propositions.md) name hypotheses, assumptions, and
conclusions. A named proposition can be nested under another with `+=`;
its declarations and updates remain inspectable in the workflow model.
The [uncertainty form](uncertainty.md) attaches named sources to a value with
`u [ ... ]`. Its description is readable at `.u`; the interpreter does not
calculate or propagate uncertainty.

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
construction, `extends`, `is` tests, and `... implement` checks. Imported stage names
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

The [interface entry specification](interfaces.md) defines the shared rule:
required entries and defaults are grouped in `must [...]`; bare entries
outside, without defaults, are optional.

A separate `#lang sciencelogo` file can declare an interface for parts of a method:

```text
interface "Assessment-process" [
  version "1"
  must [collect review report]
  supplementary-notes
  affects collect review
  affects review report
]
```

An interface may have one nonempty `version`, or omit it. `must [...]`
declares required entries and a bare name outside, without a default, declares
an optional one. A defaulted entry is compulsory even outside the group;
the documentation groups all compulsory entries inside it for clarity.
All part names must be unique. An omitted optional
part does not cause a missing-part finding; providing an undeclared part still
causes an unknown-part finding. Each
`affects source target` names two required parts; it says that a missing source
can affect the target. This is a structural dependency, not a measured
uncertainty calculation. Data interfaces use the same compulsory and optional
entry rules.

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

An investigation maps its stages to those parts with direct `implement`
references. It uses the existing `include` rule for a local interface:

```text
workflow "How will we review the data?"
include "requirements/review.rkt"
"Collect" implement Assessment-process.collect
"Review" implement Assessment-process.review
"Report" implement Assessment-process.report
stage "Collect"
stage "Review"
stage "Report"
```

The quoted name identifies a stage. A procedure uses its unquoted name, and
a value uses its name or dotted path. For example, inside a state stage,
`information.period.u implement Pendulum-protocol.documentation.uncertainty`
identifies the data addressing that nested requirement. Imported interfaces
use the existing library alias, as in `prot.Pendulum-protocol.measurement`.
These forms use no `must` prefix and do not run work or change values.

A mapping to a parent covers its required descendants; optional entries
remain optional. A mapping to one child does not claim its siblings. Many
workflow parts may map to one requirement, and one part may map to several.
The reader checks references. The model preserves the subjects, target paths,
interface version and source revision, and declaration locations. The assessor
checks required mapping presence and follows declared `affects` links from
missing parts. It does not establish scientific conformity. An issue causes
the command to exit with status 1:

```text
racket -l sciencelogo/assessor -- path/to/investigation.rkt
```

The [pendulum mapping example](../examples/protocol-mapping.rkt) maps a stage
and its uncertainty description to a local versioned protocol. The older
file-reference form, `implements "path.rkt" as alias [provide part by "reference"]`,
remains supported for references written as text; the
[self-description example](../examples/meta-assessor/README.md) exercises it.
Interface versions are displayed in assessments; this slice does not compare
versions or judge scientific adequacy.

## Inspect the specified method

The Racket module `sciencelogo/workflow-model` provides `read-workflow-model` for an
investigation file and `read-interface-model` for an interface file. The first returns
separate records for the workflow, stages, procedures, activities, named input and result slots,
imports, interface claims, and typed relations. Method elements carry source locations;
the workflow revision reflects its source and resolved library definitions. Direct
imports record their resolved Git commits; imported procedures retain source references.
A `do` call has an `invokes` relation to its procedure. Sequential
commands have `precedes` relations; a named result has `produces` and `uses` relations.
The first assignment to a name produces a value slot; later assignments record
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
structured condition checks and findings. A compulsory interface entry is represented
as a `required-entry` condition whose current evidence, for a workflow-part
check, is a matching mapping declaration. A satisfied
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
value named earlier with `as` or assignment in the current block or an enclosing block. A value
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
trial = [
  temperature = 0.8
  prompt = "tell me the capital of Peru"
]
print trial.temperature
```

The field names are labels, and the values can be quoted text, exact numbers,
expressions, lists, or other values with named fields. Field names are unique.
`trial.temperature` reads a field and raises an error if `trial` has no
named fields or lacks `temperature`. Field order does not affect equality.
The brackets still denote an ordinary list when they do not begin with
`name = value`: `[x y]` contains two named values, and `[[1 2] [3 4]]`
contains two rows. Parenthesize a comparison meant to be a list item, as in
`[(x == y)]`. The language supplies this generic structure; libraries can
define what particular fields mean.

Dot paths read nested content throughout expressions: `trial.clock.time`
reads `time` within `clock`. `trial.[temperature prompt]` selects those two
named fields into a new record; it does not introduce two local variables.
`trials.[2]` selects the second item of a list. Brackets after a dot can
also specify several updates. For example:

```text
human = [species = "human" gender = "unspecified"]
john = human.[gender = "male"]
earlier = john
john.[height = 193]
```

`earlier` still has the value it received before the update, while
`john` now also has `height`. `john.height = 194` updates one field.
A plain `another = john` assigns the same value. Quoted text such as `"male"`
is literal; an unquoted name refers to a value defined earlier. A record
interface may supply defaults when constructing a new record. It also states
structural obligations that can be checked independently with `implement`.

A record interface may be declared directly in a workflow:

```text
interface "Timing" [must [duration unit = "seconds"] notes]
trial = Timing.[duration = 2]
trial implement Timing
```

`duration` and `unit` are required; `unit` defaults to `"seconds"` and can be
overridden with `trial.unit = "minutes"`. `notes` is optional and may be
absent. Additional fields are allowed. A record made without the constructor
can also satisfy the interface. Required fields reject `unknown` unless
their declaration explicitly defaults to it. `must [duration = unknown]`
both permits an unknown duration and supplies it as the default. A supplied
default such as `unit = "seconds"` does not permit an unknown override.
Concrete defaults also declare the field's outer kind: `unit` accepts text,
and `must [duration = 2]` requires a number with default `2`.
Use `must [duration is number]` to require a number without a default, or
`must [duration = unknown number]` to allow a number or explicit unknown
with default `unknown`. The five kinds are `number`, `text`, `boolean`,
`list`, and `record`; a record is an object with named fields. These checks
apply during construction and interface checks, without attaching permanent
kind restrictions to workflow variables. List and record kinds constrain
their outer values; requirements on their contents remain separate.
`must [timing = unknown Timing]` uses a named interface in the same suffix
position. It supplies and permits unknown; a supplied object must satisfy
`Timing` without having missing child defaults inserted. The field remains
compulsory. Targets may be local, defined later, included, imported, or a
nested interface group. See [named unknown defaults](interfaces.md#unknown-defaults-with-named-interfaces).
See [value kinds](interfaces.md#value-kinds-and-defaults).
Outside `must [...]`, `notes is text` makes `notes` optional and checks it
when supplied. The same form can use a named interface, such as
`review is Review`. It supplies no default and leaves absent fields absent.
A supplied unknown value leaves this constraint undetermined. Bare optional
fields without constraints can still be absent or unknown. See
[optional field constraints](interfaces.md#constraints-on-optional-fields).
A standalone interface file can be checked with
`trial implement "relative/path.rkt"`. The assessor checks field
presence and kinds from direct assignments and dotted updates. When the record depends on
a procedure result or control flow it reports undetermined. Both local and
standalone interfaces may omit `version`; assessments retain the source
revision hash.

`must [...]` can also contain value requirements, such as
`must [swing-count > 10 swing-height unit == "seconds"]`. The referenced
entries must be present and the expressions must hold. A bare entry such
as `swing-height` requires a supplied value other than `unknown`, unless
its declaration defaults to `unknown`. Equality requirements use `==`
and supply no default; `unit = "seconds"` remains an overridable default.
The [value-requirement specification](interfaces.md#requirements-on-values)
defines mixed groups, nesting, and unknown values.

`must [timing is Timing]` requires a nested object to satisfy an existing
interface. The same `timing is Timing` is available in ordinary expressions.
The target can be local, included, imported as `alias.Timing`, or a named
nested interface group. Matching checks structure without inserting defaults;
use `Timing.[...]` to construct an object with defaults. Extra fields are
allowed. Known violations return false, unresolved checks return unknown
unless another requirement already establishes a failure, and an unknown
whole object returns unknown. The target interface's required-field and
unknown rules apply unchanged. See [interface reuse](interfaces.md#reuse-an-interface-for-a-field)
and the [runnable example](../examples/nested-interfaces.rkt).

An interface or named part may use the existing `if [...] else if [...] else
[...]` forms to make entries conditional. Conditions refer to entries of
that part; branch entries retain the same compulsory, default, and optional
rules. The reader preserves the guards for mapped protocol requirements.
Record construction applies active defaults and requirements, and the
structural check reports unresolved requirements as undetermined. See
[conditional requirements](interfaces.md#conditional-requirements) for the
full syntax and a runnable example.

`trial += [unit = "minutes" note = "hand timed"]` updates the existing
`unit` field and adds `note`. The right side of a record update is written
with named fields, and `trial` must already exist. An existing numeric field
can be increased with `trial.duration += 2`; known numeric values must be
exact numbers. A missing field is created with `=` or a record update, not
with numeric `+=`.
For an existing list, `list-name += value` appends one item. If the value is
itself a list or record, that whole value is the new item. The
[proposition contract](propositions.md) uses `+=` to add a named child,
with a duplicate-name check for that child collection.

Record interfaces can inherit and combine other record interfaces:

```text
interface "Timed-observation" [
  extends Timing
  extends Location
  must [observation unit = "minutes"]
]
interface "Timing" [must [duration unit = "seconds"]]
interface "Location" [must [place]]
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
requires all resolved compulsory fields. An `implement` check uses those same resolved
fields. `Combined.[]` can construct an interface when no required field remains to be
supplied. Standalone interface files cannot use local `extends` references.
An interface may declare nested fields inside `must [...]`, such as `clock.time` and defaults such
as `clock.unit = "seconds"`. Missing containing fields are created as records;
an existing containing value must be a record.

An interface may also use `for each item in collection [...]` to describe
requirements for each list item. The block uses the existing entry,
comparison, default, and conditional forms, with dotted paths beginning
with its local item name. Empty lists have no items to check; unknown lists
remain undetermined. The reader preserves the collection and nested body
for inspection. See [list requirements](interfaces.md#requirements-for-every-item-in-a-list)
and the [runnable example](../examples/list-requirements.rkt).

## Lists, ranges, loops, and conditions

`name = value` creates a local name or updates a visible name previously
created by assignment. This separates a range's definition from its uses. For
instance, the same range can drive two parameter sweeps:

```text
workflow "Which pendulum lengths should we compare?"
lengths = range 0.25 to 1.00 step 0.25
for each length in lengths [print length]
for each length in lengths [
  if length >= 0.75 [print "longer trial"]
]
```

At command position, `name = value` assigns. A dotted target, such as
`trial.clock.time = "12:00"`, updates nested content. Within a record or
dotted update,
`field = value` supplies a field; within an interface it supplies a default.
`name += [field = value]` updates or adds record fields. On an existing number,
`name += increment` or `name.field += increment` adds the numeric expression.
On an existing list, `name += value` appends one item. These meanings depend
on the current value on the left; a scalar is never converted into a list.
Equality comparisons use `==` throughout expressions, including `if`, `while`,
`until`, and interface requirements. A comparison can be passed directly to a
procedure, as in `do check count == 10`. Parentheses group expressions.
`count = 10` after a call starts a new assignment.

Equality compares `unknown` as an explicit value: `unknown == unknown` is
`true`, `unknown == 2` is `false`, and `2 != unknown` is `true`. These rules
also apply inside lists and records. `if period == unknown [...]` therefore
directly tests the marker. A field that is absent, or a value the checker
cannot establish, is not automatically an explicit unknown. Arithmetic,
ordered comparisons, and kind tests can still return unknown when their
inputs are unknown. The [runnable example](../examples/unknown-equality.rkt)
uses this equality rule in conditional interface requirements.

`value in list` tests whether a value equals one whole item in a list.
For example, `method in ["manual" "video"]` is the same condition as
`method == "manual" or method == "video"`. The list can be named, accessed
through a dotted path, or produced by a range. Membership
works in assignments, procedure arguments and outputs, conditions, and
interface requirements. `not (value in list)` negates it.

Membership uses the existing equality rules without coercing values or
searching inside nested items. A matching item gives `true`; if every comparison
is false, it gives `false`. An empty list always gives `false`, including
`unknown in []`. Unknown is a comparable item: `unknown in [unknown]` is
`true`, while `2 in [unknown 1]` is `false`. An unknown list gives an unknown
result, as can an operand the checker cannot establish.
The [membership example](../examples/list-membership.rkt) uses a named list
and an interface requirement.

The same operator checks record field presence: `field in record`. For
example, `period in [period = unknown]` is `true`, and
`notes in [period = 2]` is `false`. The left word is the unquoted field name,
even if a variable with that name exists; it need not be declared as a
variable. With a list on the right, the left operand instead supplies a
value, so `method in methods` uses the value of `method`.

Field presence checks only immediate keys, regardless of their values.
`unknown` and `false` values still count as present. Use a nested receiver,
such as `notes in trial.details`, to check inside a record. Quoted text and
other value expressions are not record field selectors. An unknown receiver
gives `unknown`; a known receiver other than a list or record is an error
when run. Both checks work in all expression positions. See the
[field-presence example](../examples/field-presence.rkt).

The range is an ordered sequence of exact numbers. It includes the end only
when a whole number of steps lands on it. Its bounds and step can also be
procedure inputs or previously named values. A zero step or a step moving away
from the end is an error. `[0.25 0.50 0.75]` is a list literal; lists can contain
other values or lists. A `for each` collection must evaluate to a list. Nested
`for each` blocks express combinations of parameters. These forms describe and
run the iteration of the written method; `print` still only displays text.

The reserved list property `.count` reports the number of items, including
unknown item values. An empty list has count 0; an unknown list has an
unknown count. It is read only: change the list rather than assigning to
its count. `must [measurements.count >= 3]` can require a minimum number of
items, alongside per-item interface requirements. The count is computed
from the list and does not introduce a separately supplied protocol part.
It also works on ranges and nested lists, such as `grid.[1].count`.
The reservation applies to lists. A record may have an ordinary mutable
field named `count`, with the usual assignment and default rules.
`count` is also a valid variable or procedure input name.

List positions start at 1. `lengths.[1]` reads the first value;
`lengths.[0]` is an error. An index can be a named value or expression,
as in `lengths.[position]` or `lengths.[1 + 1]`. It must be an
exact positive integer within the list. A matrix represented as a list of
rows uses the same rule at each level: `grid.[1].[2]` reads the
second value of the first row. `lengths.[2] = value` replaces an existing
position. A numeric range may still start at zero because its values
are not list positions.

`repeat 3 [ ... ]` runs a block a fixed number of times; its count must be a
nonnegative integer. `while condition [ ... ]` tests before each iteration.
`repeat [ ... ] until condition` runs at least once and tests afterward. The
post-test condition can use a value named inside the block for that iteration.
Each iteration has a fresh local scope, so new names do not leak into the
next iteration or the surrounding block. An assignment inside that block can update
a visible assigned name from an enclosing block. Procedure inputs, `as` results,
and `for each` iteration names cannot be updated this way. This makes a
terminating condition possible, for example:

```text
continue = true
while continue [
  print "One planned pass"
  continue = false
]
```

A changing count can be written `attempts = attempts + 1`. Arithmetic
supports `+`, `-`, `*`, and `/` on exact numbers. A finite decimal quotient
is displayed as a decimal; another rational quotient is displayed as a
fraction, such as `1/3`. Division by zero is an error. Expressions also work
in range bounds and steps, repeat counts, lists, outputs, and procedure
arguments. For example, `do add 1 + 2 (3 * 4) as total` supplies two inputs.

`if condition [ ... ] else if another-condition [ ... ] else [ ... ]` runs the
first branch whose condition is true, or the optional `else` branch. Conditions
can combine Boolean values and comparisons with `==`, `!=`, `<`, `<=`, `>`,
`>=`, or `in`. `value is kind` checks one of the five outer value kinds and
has comparison precedence. A known value produces a Boolean result; an
unknown value leaves the result unknown. For instance, `[unknown] is list`
is true, while `unknown is number` is unknown. Kind names are contextual
after `is` and after an interface's unknown default; `is` is reserved.
After `is`, a named interface checks its full structure instead of only
the outer kind. Local, included, imported, and nested-group references
use the same matching rules described above.
Ordered comparisons require numbers. `not` reverses a Boolean value,
`and` needs both sides true, `or` needs either side true, and `xor` needs
exactly one side true. Precedence from strongest to weakest is parentheses,
unary `-`, `*` and `/`, `+` and `-`, comparisons, `not`, `and`, `xor`, then
`or`. Dotted access binds more tightly than unary `-` and arithmetic.
Operators at one level associate left to
right. Comparisons cannot be
chained; combine them with `and`. `unknown` explicitly represents an
undetermined value. `false and unknown` resolves to `false`, and `true or
unknown` resolves to `true`. An undetermined or nonboolean condition raises
an error rather than selecting
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
