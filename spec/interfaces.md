# Interface entries

**Status:** accepted compact syntax. The reader, record constructors, and
structural checks use the same compulsory and optional entry rules. The
earlier `require` notation is rejected; `must [...]` is the interface
requirement form.

An interface can describe fields of a structured data object or named parts
of a workflow. Both uses share the following declaration rule:

```text
interface Timing [
  must [duration unit = "seconds"]
  notes
]
```

- `must [...]` makes every entry inside its brackets compulsory. The group
  may span lines. For example, `must [duration unit]` requires both fields.
- `field = value` supplies an overridable default. The field is compulsory
  and present even when a default is declared outside `must [...]`.
  A concrete default also declares the field's broad value kind.
- A bare entry outside `must [...]`, without a default, is optional and may
  be absent.
- `field is kind-or-interface` outside `must [...]` is also optional. The
  constraint applies when that field is supplied and supplies no default.

Required data fields must be present and reject `unknown` by default. A
default supplies a field when no override is given. A required field without
a default must be supplied when constructing the object. Required workflow
parts must be provided through the existing mappings.

In the example, both `duration` and `unit` must be present. `duration` has no
default; `unit` defaults to `"seconds"` and accepts text values such as
`"minutes"`. Neither accepts an override of `unknown`. `notes` may be absent.

## Value kinds and defaults

An interface can require a `number`, `text`, `boolean`, `list`, or `record`.
A record is an object with named fields, such as `[period = 2 unit = "seconds"]`.

| Declaration | Meaning |
| --- | --- |
| `must [period is number]` | Requires a number; supplies no default. |
| `must [period = 2]` | Requires a number; defaults to `2`. |
| `must [period = unknown number]` | Requires a number or explicit `unknown`; defaults to `unknown`. |
| `must [timing = unknown Timing]` | Requires an object matching `Timing` or explicit `unknown`; defaults to `unknown`. |
| `must [period = unknown]` | Supplies and permits `unknown`, with no kind restriction. |

Concrete defaults infer only the outer kind: a list default requires a
list, and a record default requires a record. They do not constrain list
items or require the default record's fields; declare those requirements
separately. A qualified numeric default such as `2 u []` infers `number`.
Other default expressions infer the kind of their default value, independently
of an override. If a check cannot establish that kind, it remains undetermined.

The suffix after an unknown default can use any of the five kind names
or a declared interface reference.
For example, `must [measurements = unknown list]` allows a list or explicit
`unknown`. Without the suffix, `unknown` supplies no concrete kind.
Kind names are recognized in this position and after `is`; they remain
available as ordinary names elsewhere. In `period = unknown number`,
`number` qualifies `period`; a separate entry named `number` belongs in
another `must [...]` group or before that default.

Kinds constrain interface construction and checks. They do not attach a
permanent restriction to workflow variables. A later update can be inspected
by checking the object against its interface again. Inheritance, imports,
and includes preserve the default and explicit kind; redeclaring a field
replaces its default, inferred kind, and unknown permission together.

`value is kind` is also a Boolean expression, available in ordinary
conditions, procedure inputs and outputs, and interface requirements.
It examines only the outer value, ignoring an attached `u` description.
Thus `[unknown] is list` is true, while `unknown is number` is unknown.
It uses comparison precedence and cannot be chained with another comparison.
An expression such as `period is number` remains undetermined for an unknown
period even if another declaration permits that unknown. Use the compact
`period = unknown number` declaration when unknown is an allowed field value.
The [runnable example](../examples/value-kinds.rkt) shows measured and planned
periods.

## Constraints on optional fields

```text
interface Timing [
  must [period is number]
  notes is text
]
```

`period` is compulsory. `notes` can be absent; when present, it is checked
as text. The optional form accepts any of the five kinds or a named
interface, such as `review is Review`. Local, included, imported, and
nested-group interface references work as they do in required tests.

| Form | Presence and check |
| --- | --- |
| `notes` | Optional, with no value constraint. |
| `notes is text` | Optional; checks supplied values as text. |
| `must [notes is text]` | Required; checks the supplied value as text. |
| `must [notes = "default"]` | Required, with an overridable text default. |

The optional `is` form supplies no default and inserts no field during
construction. Constraints apply in their declared conditional branch and
parent group. They also work in `for each`, where the field uses the local
item name, such as `item.notes is text`. Inheritance retains the constraint;
redeclaring the field replaces its complete declaration. Duplicate and
conflicting inherited declarations follow the existing field rules.

An absent optional field is skipped. A supplied value of the wrong kind or
an object that fails its named interface gives a violation. A supplied
`unknown` leaves the constraint undetermined, as an ordinary `is` test does.
An unavailable value also remains undetermined. The constructor reports an
undetermined value requirement if a supplied optional value cannot be
checked. Bare optional fields without constraints can still contain unknown
without a kind check. Required fields keep their existing unknown rules.

The reader retains the constraint separately from the default and presence
flag, as `(interface-field notes #f #f #f (kind-test text ((result notes))))`.
The model has an `optional-entry` for presence and a `field-constraint`
condition scoped to that entry. References inside this constraint do not
create inferred required entries. Its source location, enclosing guard,
and resolved interface target remain inspectable. See the
[runnable example](../examples/optional-fields.rkt).

## Reuse an interface for a field

`value is Interface` checks an object against an existing interface. The
same expression can be a field requirement:

```text
interface Timing [
  must [period is number unit = "seconds"]
]
interface Experiment [
  must [timing is Timing]
]

timing = Timing.[period = 2]
experiment = Experiment.[timing = timing]
```

`timing` must be present and satisfy the required fields, kinds, conditions,
nested groups, per-item rules, and inherited requirements of `Timing`.
Extra fields are allowed. Matching is structural: an object built directly
with named fields can match, without having been constructed from the
interface.

The test supplies no default and never modifies its operand. In particular,
`[period = 2] is Timing` is false because `unit` is absent. Constructing
`Timing.[period = 2]` supplies that default. An overridable default retains
its ordinary meaning: `[period = 2 unit = "minutes"] is Timing` is true.

Named tests work wherever expressions work, including `if`, `else if`,
procedure inputs and results, and interface guards and requirements.
The target may be defined later, included, imported as `alias.Interface`,
or name a nested group such as `Protocol.documentation`. Existing import
visibility rules apply; private dependency aliases are not exposed. Unknown
targets and references to a value field rather than an interface or group
are reader errors. No new source keyword is introduced.

An unknown whole object yields `unknown`. Known non-records, missing
required fields, disallowed unknown fields, wrong kinds, and false
requirements yield false. An unresolved check yields `unknown` if no known
failure has been found. The interface's existing unknown permissions apply
to its own fields; permitting unknown for an enclosing field does not make
`unknown is Timing` true. Recursive references may check finite nested
records. Repeating the same interface test on the same object without
settling it yields unknown rather than recursing indefinitely.

The reader preserves a named test as `(kind-test Timing ((result timing)))`.
The target is an interface reference, not a workflow variable. Library
expansion qualifies it, and interface models retain the declarations needed
to interpret referenced interfaces. Checks use that retained definition
context rather than fetching a new version of the interface.
See the [runnable example](../examples/nested-interfaces.rkt).

## Unknown defaults with named interfaces

```text
interface Timing [
  must [period is number unit = "seconds"]
]
interface Experiment [
  must [timing = unknown Timing]
]

experiment = Experiment.[]
experiment.timing = Timing.[period = 2]
experiment implement Experiment
```

`timing` is compulsory. Construction supplies and permits `unknown`.
A supplied non-unknown value must satisfy `Timing`, including its field,
kind, value, nested, conditional, and inherited requirements. Matching is
structural, so plain records can match and extra fields are allowed.
No child defaults are inserted during this check: `[period = 2]` fails
because `unit` is missing. An existing record that omits `timing` also
fails; permitting unknown does not permit absence.

Targets use the same unquoted references as `is`: local and later
definitions, included definitions, imported `alias.Interface` names, and
nested groups such as `Protocol.timing`. Source dependency visibility is
unchanged. Inheritance retains the default, named target, and permission;
redeclaring the field replaces them. Conditional and per-item declarations
use the same rule.

The reader recognizes an immediately following bare interface reference
using the assembled declarations, including imports and includes. This
does not depend on capitalization. A word that does not identify an
interface retains its ordinary entry meaning, so `must [period = unknown notes]`
still declares two fields when `notes` is not an interface name.
To name a separate field after an unknown default when it has the same
name as an interface, put it in a separate `must [...]` group or before
the default. A following entry with its own `=` or `is` is kept as a
separate declaration or condition. A recognized reference to a missing
nested group or to a value field is a reader error.

An unavailable supplied value leaves the named check undetermined, unless
another known failure settles it. A supplied `unknown` is accepted by this
declaration. Additional conditions retain their own semantics:
`must [timing = unknown Timing timing is Timing]` remains undetermined
when `timing` is unknown.

The model retains `(typed-default Timing ((literal unknown)))`, qualifying
the target through library imports and retaining its definition context.
It creates one required field, without a separate entry for the suffix.
See the [runnable example](../examples/interface-defaults.rkt).

## Permit unknown explicitly

Declare a default of `unknown` to permit it for a required field:

| Declaration | Meaning |
| --- | --- |
| `must [period]` | A value must be supplied; `unknown` is rejected. |
| `must [period = 2]` | Defaults to `2`; an override must be a number. |
| `must [period = unknown]` | Permits `unknown` and supplies it as the default. |

The field remains compulsory in all three cases. A check of an existing
record does not add missing defaults, so an absent field still fails that
check. An explicitly supplied `unknown` is a present value, not an omission;
it violates a required field unless its declaration permits it. An unresolved
value whose contents the checker cannot establish remains undetermined.

The permission belongs to the field's resolved declaration. Inheritance,
imports, and includes preserve it. Redeclaring an inherited field replaces
its default and permission under the existing override rules. Conditional
declarations apply only in their active branches. A default of `unknown`
written outside `must [...]` has the same meaning; documentation groups
all compulsory fields inside the brackets.

This rule concerns the required field's value. A supplied list or record
can contain unknown entries; requirements on its contents are checked
separately. Optional fields may still be absent or contain `unknown`.
Additional value conditions keep their own meaning: permitting an unknown
`period` does not establish `period > 0`. The comparison stays undetermined
until its value can be established. Equality and inequality compare the
explicit marker: `unknown == unknown` is true, `unknown == 2` is false,
and `unknown != 2` is true. The same rule applies within lists and records.
An absent entry or a value the checker cannot establish is not implicitly
an explicit `unknown`.

An attached `u` description does not make an unknown underlying value
known. The same permission rule applies to a qualified `unknown`;
a default such as `period = unknown u []` also permits it.
The [runnable example](../examples/unknown-fields.rkt) shows a supplied
period and an interface that explicitly permits a pending period.

## Presentation in documentation

Group every compulsory entry inside `must [...]`, including entries with
defaults. Keep optional entries outside. A default written outside the
group remains compulsory; grouping it is a presentation convention that
makes requiredness visible in one place.

Use the same presentation for workflow parts:

```text
interface Pendulum-recording [
  version "1"
  must [measurement]
  supplementary-notes
]
```

`measurement` is required; `supplementary-notes` is optional. `must` replaces
`require` as the requirement marker in interface declarations.

## Requirements on values

`must [...]` can mix required entries and conditions on their values:

```text
interface Timing-trial [
  must [swing-count > 10 swing-height unit == "seconds"]
]
```

This requires `swing-count` to be present and greater than 10,
`swing-height` to be present, and `unit` to be present and equal to
`"seconds"`. A bare required entry rejects `unknown` unless its declaration
defaults to `unknown`. Entries referenced by value requirements follow the
same default rule, using any existing declaration's permission. A value
condition can remain undetermined when it uses a permitted unknown value.

Conditions use `==`, `!=`, `<`, `<=`, `>`, `>=`, and `in`, with the existing
arithmetic and Boolean operators. For example:

```text
must [swing-count > 10 and swing-count < 100 swing-height]
```

The first expression is one condition; the following bare `swing-height`
is another required entry. Whitespace separates entries; parentheses can
group expressions. Names in a condition identify entries in the surrounding
interface part. Each referenced entry must be present when that requirement
applies. Existing declarations and defaults are reused, so a value condition
does not require a repeated field declaration. Dotted paths access nested
entries. These references are available through the existing interface
mapping syntax, including entries introduced by a value requirement.

`=` and `==` have distinct meanings throughout the compact language:

| Form | Meaning |
| --- | --- |
| `must [unit = "seconds"]` | Supplies an overridable default. |
| `must [unit == "seconds"]` | Requires the supplied value to equal `"seconds"`; supplies no default. |

Use these as separate forms in documentation. The same equality operator is
used in `if`, `while`, `until`, and other expressions. Assignments and record
entries continue to use `=`.

Value requirements can appear in conditional branches and nested parts.
Inheritance preserves them alongside fields and defaults. Constructing a
record checks applicable requirements after filling defaults. A false
condition fails construction; an unresolved value requirement is reported
as undetermined. Checking an existing record leaves its values unchanged.

The reader preserves each requirement's expression, enclosing part, guard,
and source location. The structural record check evaluates requirements
whose values can be established from the written record. The workflow-mapping
check retains requirements on mapped values as undetermined when it cannot
resolve those values. Applications can inspect the same expressions and
data mappings. The [runnable example](../examples/value-requirements.rkt)
uses the mixed form above.

### Require one of several values

List membership uses `in`:

```text
interface Timing [
  must [method in ["manual" "video"]]
]
```

This requires `method` to equal `"manual"` or `"video"` and supplies no
default. The right side can also be a named list field, a dotted path, or
another expression yielding a list. Names refer to entries of the surrounding
interface part, so a reusable default list can be declared alongside the
requirement:

```text
must [methods = ["manual" "video"] method in methods]
```

Both fields are required. Construction fills the `methods` default;
checking an existing record requires that field to be present without
inserting it. The same membership form works in conditional requirements,
nested groups, and per-item requirements. Inheritance and imports preserve it.

Membership has the meaning of equality comparisons joined with `or`, using
whole items and the existing `==` rules. The marker is a comparable item:
`unknown in [unknown]` is true, while `2 in [unknown 1]` is false.
If every comparison is false, the result is false; an empty list always
gives false. An unknown collection or an operand the checker cannot
establish can leave membership undetermined. The required-field
rules still apply: an explicitly unknown required field is rejected unless
its declaration permits it. Permitting an unknown does not establish a match.

The same syntax checks a record for an immediate field:

```text
interface Trial [
  details [notes]
  if notes in details [must [reviewer]]
]
```

With a record receiver, the bare word `notes` is its field label, not a
separate value required in `Trial`. The optional field stays optional.
The branch applies whenever the key exists, including when its value is
`unknown`. `must [notes in details]` requires presence without constraining
the field's value. Nested receivers, groups, per-item rules, and inherited
interfaces use the same interpretation.

The reader preserves both checks as `(compare in (left right))`.
A bare `(result name)` on the left is contextual: a field label for a record,
a value reference for a list. The model guards a candidate value dependency
or inferred required entry with `(kind-test list (right))`; it does not make
a separate value compulsory when the receiver is a record. The checker
resolves this using the supplied receiver. An unavailable receiver remains
undetermined, rather than being treated as an empty record.
The operator uses comparison precedence and
cannot be chained with another comparison. See the
[general expression rules](first-slice.md#lists-ranges-loops-and-conditions)
and the [runnable example](../examples/list-membership.rkt).

## Nested parts

A name followed by brackets describes child entries. The declaration rule
applies independently at each level:

```text
interface Pendulum-protocol [
  version "1"
  must [
    measurement
    documentation [
      must [uncertainty]
      notes
    ]
  ]
  additional-measurements
]
```

This syntax declares required `measurement` and `documentation` parts.
`documentation.uncertainty` is required within `documentation`;
`documentation.notes` and the top-level `additional-measurements` are
optional. A default is compulsory in its parent scope. An optional parent
may be absent; its required children apply when that parent is present.

Nested names use dots, including
`Pendulum-protocol.documentation.uncertainty`. Entries must be unique within
their parent. Distinct parents may reuse a child name; declarations that
produce the same complete path are duplicates. The root interface version
identifies the whole hierarchy.

## Conditional requirements

Use the existing `if [...] else if [...] else [...]` syntax inside an
interface or one of its named parts:

```text
interface Timing-protocol [
  version "1"
  must [method]

  if method == "automatic" [
    must [instrument unit = "seconds"]
  ] else if method == "video" [
    must [frame-rate]
  ] else [
    must [observer]
  ]
]
```

`method` is always required. Automatic timing requires `instrument` and
`unit`; its unit defaults to `"seconds"`. Video timing requires `frame-rate`.
The final branch requires `observer` for other timing methods. The branches
use the existing comparison and Boolean expressions. They follow the same
order as ordinary conditionals: an `else if` or `else` branch applies only
when preceding conditions are false. Both `else if` and `else` are optional.

Names in a condition refer to entries in the surrounding interface part.
Inside `measurement [...]`, for example, `method` identifies
`measurement.method`. Dotted paths access nested fields with their usual
meaning. The entries may be declared later or inherited from a parent
interface. Conditions cannot refer to procedure inputs or unrelated workflow
variables. A workflow supplies its own values through the existing mappings,
such as `information.timing-method implement Timing-protocol.method`.

The existing entry rules apply within each branch: `must [...]` marks
compulsory entries, a defaulted entry is compulsory, and a bare entry without
a default is optional. A default applies only when its branch applies.
An inactive branch does not prohibit supplying its entries as additional
fields or mappings. Names remain unique throughout each named part,
including its conditional branches. Branches contain interface entries and
can contain further conditionals; `version` and `extends` remain at the
interface declaration level. An `affects` link written inside a branch
retains that branch's condition.

Construction applies active defaults and checks active required fields.
To permit an unknown timing method, declare `must [method = unknown]`.
If an omitted required field depends on an unknown condition, construction
reports an undetermined conditional requirement. An ordinary record can
still describe unknown values and be mapped to the interface for inspection.
The structural record check reports such unresolved requirements as
`undetermined`, rather than treating the condition as false.
Equality with an explicitly supplied marker is resolved: an unknown
`method` makes `method == "automatic"` false and `method == unknown` true.
Use `if method == unknown [...]` to describe requirements for that case.
The [unknown-equality example](../examples/unknown-equality.rkt) requires an
explanation for a pending period and a positive number otherwise.

The reader and workflow model retain the condition, requiredness, hierarchy,
and source location. Inherited and imported interfaces preserve their
conditions. The structural workflow-mapping check resolves literal
conditions; conditions depending on mapped workflow values remain
undetermined when required mappings are absent. Applications can use the
preserved conditions and mappings to assess protocol conformity.

The [conditional interface example](../examples/conditional-interface.rkt)
constructs records for all three branches and checks their declared fields.

## Requirements for every item in a list

An interface can use the existing `for each name in collection [...]` form
to describe requirements for every item of a list:

```text
interface Timing-series [
  must [measurements]

  for each measurement in measurements [
    must [measurement.period measurement.period.u]
  ]
]
```

This interface requires a `measurements` list. Each item must have a
`period` field and an attached uncertainty description accessible through
`period.u`. The presence of a description says nothing about its scientific
adequacy. This block describes each item; it does not perform measurements
or run workflow activities.

The loop name denotes the current item and is available only within its
block. Entry declarations in the block begin with that name, such as
`measurement.period` or `measurement.unit = "seconds"`. The existing
required, optional, and default rules apply. A bare required entry must be
present and rejects `unknown` unless permitted; a comparison also checks
its stated condition. For example:

```text
for each measurement in measurements [
  must [measurement.swing-count > 10 measurement.unit == "seconds"]
]
```

Expressions may also read entries of the surrounding interface part.
For instance, `measurement.swing-count > minimum-count` can use a
`minimum-count` entry declared alongside `measurements`. A scalar list can
use its item name directly: `for each count in counts [must [count > 10]]`.
The collection uses the existing value expressions, including dotted
paths, lists, and ranges. A block can contain nested `for each` blocks and
the established `if [...] else if [...] else [...]` forms. An enclosing
condition can also govern a whole list requirement. Enclosing item names
remain available in nested expressions. A named child part retains the
ordinary rule that its fields and conditions are relative to that part.

When the block applies, the collection must be present and must be a list.
An empty list has no items to check and satisfies the per-item requirements;
the form does not require a nonempty list. Use the reserved `.count`
property to require a number of items:

```text
must [measurements.count >= 3]
```

This requires at least three items; `must [measurements.count == 3]`
requires exactly three. The property is computed from the list, including
positions whose values are `unknown`. It is read only and cannot receive a
default or assignment. The requirement references the list; it does not
declare an additional field or protocol part named `measurements.count`.
The full comparison remains in the model for inspection.

An explicitly unknown required collection or item field is rejected unless
its declaration defaults to `unknown`. A permitted unknown collection,
an unavailable value, or a permitted unknown needed by a condition leaves
the corresponding check undetermined.
A known violation remains a violation even if another item is unknown.
Missing item fields are identified with positions starting at 1, for
example `measurements.[2].period.u`.

Constructing a record from an interface fills applicable defaults in
the referenced list items, then checks the requirements. Checking an
existing record does not fill defaults or change it. For example,
`must [measurement.unit = "seconds"]` supplies each item's overridable
unit during construction. Default completion writes back through a named
or dotted collection location; a literal or calculated collection is only
inspected. Unknown and invalid requirements prevent construction, as with
other interface requirements.

Inheritance, imports, and includes preserve the whole block. The model
records its item name, collection expression, enclosing scope, guard, and
source location. Its body is a nested interface model that retains each
entry's source location and any further conditions or list requirements.
The item name does not become a workflow variable or a protocol part at
the enclosing level. Structural record checks inspect known written lists;
workflow mappings retain an undetermined list requirement when the mapped
values are unavailable. Applications can inspect the same declaration.
The [runnable list example](../examples/list-requirements.rkt) constructs
and checks the series shown above.

## Map workflow parts to requirements

Use `implement` directly between a workflow reference and an interface reference:

```text
Timing implement Pendulum-protocol.measurement
Report implement Pendulum-protocol.documentation
```

The unquoted names identify declared stages, including stages defined later in
the file. Stages, procedures, interfaces, and libraries all use unquoted names
in declarations and references. The reader reports an ambiguous mapping target
when a stage and another visible value or definition share that reference.
A value uses its existing name
or dotted path; inside a state stage, for example:

```text
information.period.u implement Pendulum-protocol.documentation.uncertainty
```

There is no `must` prefix. `must [...]` declares what an interface requires;
`implement` records which workflow part addresses that requirement. A mapping
does not call the procedure, change a value, or establish scientific conformity.

A mapping to `Pendulum-protocol.documentation` claims that parent and its
required descendants. Optional descendants remain optional. A mapping to
`Pendulum-protocol.documentation.uncertainty` identifies that child and its
parent as present, without claiming siblings. Parent and child mappings may
coexist. Several stages or values may map to the same requirement, and one
stage or value may map to several requirements. A stage or procedure can
reference the whole interface to claim all its required parts.

The reader rejects unknown stage, procedure, value, and requirement references.
The model preserves each mapping's source location, declaration scope,
subject, target hierarchy, and interface version and source revision. The
structural check evaluates declaration presence; external applications can
inspect the mapped work and data to assess scientific conformity.

Interfaces use the established import and include rules. For an imported
library alias `prot`, a reference is `prot.Pendulum-protocol.documentation`.
`include "relative/path.rkt"` makes local interface declarations available.
The [runnable mapping example](../examples/protocol-mapping.rkt) declares the
pendulum protocol and maps a stage and its uncertainty description.

A nested group is also a data shape. The existing forms can construct it
with `Pendulum-protocol.documentation.[uncertainty = [estimate = unknown]]` and check a
record with `record-name implement Pendulum-protocol.documentation`.
This also works for imported interfaces, using
`alias.Interface.part`. Constructing from a full interface applies nested
defaults in required groups and in optional groups that have been supplied.
Checking an existing record leaves its data unchanged.

Named groups contain entries, `must [...]` groups, and optional `affects`
links. The root declaration contains `version` and `extends`. An `affects`
link within a named group uses paths relative to that group.

## Reading and checking

Required groups may share a line with other entries or span lines. Each
group must contain at least one entry or value condition. Field declarations
are unique across all groups and the rest of their parent body; conditions
can refer to those fields repeatedly. A group contains names, defaults,
value conditions, and named blocks;
declarations such as `version` and `extends` stay outside it.

The reader preserves each entry's name, requiredness, default if any, and
source location. Named parts retain their hierarchy through child scopes
and `contains` relations; conditions use complete dotted paths. It does not infer a different kind of interface from the
presence of a requirement marker. A record check tests required field
presence, value kinds, unknown permissions, and value conditions; a stage or procedure
mapping tests required mapping declarations.
Optional entries may be supplied in either use without becoming compulsory.
Constructing a record applies defaults; checking an existing record does
not insert missing fields.

Inheritance preserves requiredness and defaults. Identical inherited entries
merge. Redundant parentheses alone do not make inherited defaults or guards
conflict; the written groups remain in their source declarations.
Conflicting inherited declarations need an explicit child declaration,
as with existing default conflicts. Child declarations replace inherited
declarations of the same entry. Local and imported interfaces support
inheritance; a standalone interface file cannot extend a local interface.

The current `affects source target` form links two compulsory entries. It
does not change which entries are required.
