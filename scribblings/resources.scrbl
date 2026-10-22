#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "resources"]{Data sources and storage}

A @tt{resource} declaration names data outside a workflow: where it would be
read from or stored. Write the declaration directly in the workflow:

@verbatim|{
#lang sciencelogo
workflow "Trace a pendulum timing"
resource timings [path = "data/timings.csv" kind = "table"]

elapsed = timings.elapsed
timings.period = elapsed
}|

The first assignment declares that @tt{elapsed} comes from the @tt{elapsed}
location within @tt{timings}. The second declares that @tt{elapsed} goes to its
@tt{period} location. A dotted path may continue into nested data, such as
@tt{timings.observations.first}. The declaration may describe a file path,
URL, database, or other storage; the language prescribes no fixed fields.
@tt{resource timings []} is also valid when the storage location is specified
elsewhere.

@tt{resource} names are unique within a workflow and cannot conflict with a
procedure, interface, performer, import alias, or stage state set name.
The declared name by itself is not a data value. To refer to data outside the
workflow, use a dotted path rooted in that name. An undeclared path is
rejected. A quoted URL or file path is ordinary text and does not read or
write anything.
The declaration fields describe the resource for inspection; a dotted path
addresses its data, not a declaration field.
The path is a logical address; an external application would interpret it for
the particular file, table, or database.
Source-code paths in @tt{import}, @tt{include}, and interface references
identify language definitions; they are separate from data paths.

@section{Read and write data in a stage}

Within a paired stage, read into a field of @tt{information},
@tt{environment}, or @tt{factors}, or write a state field to a data location:

@verbatim|{
resource timings [path = "data/timings.csv"]
performer researcher [kind = "human"]

stage Inspect-timing by researcher from state [
  information = [elapsed = unknown]
]
information.elapsed = timings.elapsed
timings.checked = information.elapsed
end stage with state [
  information = [elapsed = unknown]
]
}|

The entry and exit states remain complete declarations. When a data read
assigns into state, its target needs an existing parent set or record. A
data write may take a value from an available state field. These
assignments record the intended flow; the paired stage body is not executed.
If the stage names a performer, the workflow model links that performer to
its data assignments.

@section{Reader, model, and interpreter}

The reader checks @tt{resource} declarations, names, and stage locations. The
workflow model preserves the declaration and each assignment, with
@tt{reads-from} or @tt{writes-to} links to the named data source or destination.
The full dotted address remains in the assignment. The interpreter treats an inbound
data value as @tt{unknown} and performs no external read or write. The
model describes the written method; it does not show that data was transferred
in a particular run. The @hyperlink[(source-file-url "spec/resources.md")]{data
source and storage contract} records the accepted rules.
