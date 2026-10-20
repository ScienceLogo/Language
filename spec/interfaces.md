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
The [runnable mapping example](../examples/protocol-mapping.rkt) includes the
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
group must contain at least one entry. Entries are unique across all groups
and the rest of their parent body. A group contains names, defaults, and named blocks;
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
