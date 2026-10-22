# Data sources and storage

**Status:** accepted syntax. The reader and workflow model record data flow
through declared `resource` paths. Ordinary code treats incoming data as
`unknown` and does not access storage; paired-stage bodies remain declarations.

## Declaration and paths

```text
#lang sciencelogo
resource timings [path = "data/timings.csv" kind = "table"]
elapsed = timings.elapsed
timings.period = elapsed
```

`resource name [field = value ...]` names data outside the workflow: a source
or place to store it. The declaration is an open record: fields may describe a
URL, file, database, directory, or other storage, and `[]` is allowed. The
language requires no particular metadata field or storage format. Names
declared with `resource` are unique and cannot conflict with procedure,
interface, performer, import alias, or stage state set names. Such a name
cannot be reused for a local result or loop name.
Declarations may appear after the assignments that refer to them.

A dotted path rooted in a declared `resource` addresses data outside the
written workflow. Paths can continue through nested locations; their fields
need not be listed in the declaration. The declared name alone is
not a data value. A path with an undeclared root is rejected. A quoted URL or
file path is text and never an operation that accesses it. `import` URLs,
`include` paths, and interface file paths address ScienceLogo source code and
remain separate from the data-access rule.
The declaration's fields are descriptive metadata in the workflow model;
`timings.url` denotes a data location, not the `url` metadata
field.

## Direction and stage state

`elapsed = timings.elapsed` describes an inbound value; `timings.period =
elapsed` describes an outbound value. `=` retains its ordinary assignment
direction. Neither form asserts that a transfer happened. Outside paired
stages, the interpreter evaluates an inbound data path as `unknown` and
does not perform external I/O. An outbound assignment does not change the
external storage.

In a paired stage, a read from a declared data source can assign into a field
under an existing `information`, `environment`, or `factors` set. A data write
can refer to an available state field. The closing state still declares the complete
outgoing state. The reader checks that the source state field exists and that
the parent of an inbound target exists. Data paths themselves are open;
the reader cannot verify an external field or its contents.

```text
resource timings [path = "data/timings.csv"]
stage Inspect from state [information = [elapsed = unknown]]
information.elapsed = timings.elapsed
timings.checked = information.elapsed
end stage with state [information = [elapsed = unknown]]
```

The workflow model preserves each `resource` declaration and assignment with
its source location. A `reads-from` or `writes-to` relation identifies the
named data source or destination; the assignment retains the complete dotted
address and other expression. If the paired stage names a default performer,
that performer is linked to these declared data activities. These are links
in a written method, not observations or findings about a run.

Applications may use these declarations to inspect intended data
sources, destinations, and data flow. Their checks and any actual connector
or execution code live outside the language.
