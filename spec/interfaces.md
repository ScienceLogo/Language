# Interface entries

**Status:** accepted compact syntax. The reader, record constructors, and
structural checks use the same compulsory and optional entry rules. The
earlier `require` notation is rejected; `must [...]` is the interface
requirement form.

An interface can describe fields of a structured data object or named parts
of a workflow. Both uses share the following declaration rule:

```text
interface "Timing" [
  must [duration unit = "seconds"]
  notes
]
```

- `must [...]` makes every entry inside its brackets compulsory. The group
  may span lines. For example, `must [duration unit]` requires both fields.
- `field = value` supplies an overridable default. The field is compulsory
  and present even when a default is declared outside `must [...]`.
- A bare entry outside `must [...]`, without a default, is optional and may
  be absent.

Required data fields must be present and reject `unknown` by default. A
default supplies a field when no override is given. A required field without
a default must be supplied when constructing the object. Required workflow
parts must be provided through the existing mappings.

In the example, both `duration` and `unit` must be present. `duration` has no
default; `unit` defaults to `"seconds"`. Neither accepts an override of
`unknown`. `notes` may be absent.

## Permit unknown explicitly

Declare a default of `unknown` to permit it for a required field:

| Declaration | Meaning |
| --- | --- |
| `must [period]` | A value must be supplied; `unknown` is rejected. |
| `must [period = 2]` | Defaults to `2`; an override cannot be `unknown`. |
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
until its value can be established. Ordinary comparisons with `unknown`
retain their existing behavior.

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
interface "Pendulum-recording" [
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
interface "Timing-trial" [
  must [swing-count > 10 swing-height unit == "seconds"]
]
```

This requires `swing-count` to be present and greater than 10,
`swing-height` to be present, and `unit` to be present and equal to
`"seconds"`. A bare required entry rejects `unknown` unless its declaration
defaults to `unknown`. Entries referenced by value requirements follow the
same default rule, using any existing declaration's permission. A value
condition can remain undetermined when it uses a permitted unknown value.

Conditions use `==`, `!=`, `<`, `<=`, `>`, and `>=`, with the existing
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

## Nested parts

A name followed by brackets describes child entries. The declaration rule
applies independently at each level:

```text
interface "Pendulum-protocol" [
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
interface "Timing-protocol" [
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
interface "Timing-series" [
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
"Timing" implement Pendulum-protocol.measurement
"Report" implement Pendulum-protocol.documentation
```

The quoted names identify declared stages, including stages defined later in
the file. A procedure uses its unquoted name. A value uses its existing name
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
presence, unknown permissions, and value conditions; a stage or procedure
mapping tests required mapping declarations.
Optional entries may be supplied in either use without becoming compulsory.
Constructing a record applies defaults; checking an existing record does
not insert missing fields.

Inheritance preserves requiredness and defaults. Identical inherited entries
merge. Conflicting inherited declarations need an explicit child declaration,
as with existing default conflicts. Child declarations replace inherited
declarations of the same entry. Local and imported interfaces support
inheritance; a standalone interface file cannot extend a local interface.

The current `affects source target` form links two compulsory entries. It
does not change which entries are required.
