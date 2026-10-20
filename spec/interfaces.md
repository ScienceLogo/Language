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

Required means that the field or workflow part must be present. It does not
mean that its value must always be supplied explicitly: a default supplies
the field's value when no override is given. A required data field without
a default must be supplied when constructing the object.

In the example, both `duration` and `unit` must be present. `duration` has no
default; `unit` defaults to `"seconds"`. `notes` may be absent. An explicit
`unknown` is a present value, not an omitted field.

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
`"seconds"`. A bare entry requires presence only; its value may be `unknown`.
A value condition can itself be undetermined when a referenced value is
`unknown`.

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
with `Pendulum-protocol.documentation.[uncertainty = unknown]` and check a
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
presence; a stage or procedure mapping tests required mapping declarations.
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
