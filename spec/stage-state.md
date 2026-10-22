# Paired stages and state locations

The reader validates the written method and
retains the stage and calls in its model. The interpreter does not execute a
paired stage's body or produce an observed run. See the [manual page](../scribblings/stages.scrbl)
for a guided explanation and [context sets](context.md) for the scientific
distinction among information, environment, and considered factors.

## Boundaries

`stage name from state [ ... ]` begins a paired stage. `end stage with state
[ ... ]` closes it. The verbose opening is `start stage name from state
[ ... ]`; the closing form is shared. Both state objects are
mandatory, including when empty (`state []`). A paired stage is a section and
checkpoint, not a callable procedure or a new variable scope. Its unquoted
identifier must be distinct among stage names in the assembled workflow.

The state object's only top-level set names are `information`, `environment`,
and `factors`. Each present set is a record of named fields or an empty list
`[]`. The sets are optional individually; an absent set, a present empty set,
and a set containing a field whose value is `unknown` are different. Nested
records may supply further fields. Dots in a location separate field names;
field names themselves cannot contain dots.

The opening state describes what enters. The closing state describes the full
state leaving the stage, including unchanged fields. Writing a new value only
at the closing boundary does not explain how the stage obtained it. The older
`stage name` header form remains runnable and labels following commands
until the next header or enclosing block's end.

## Performers

`performer name [field = value ...]` declares a named performer object directly
in a workflow. An empty object, `performer name []`, is valid. The language
does not require particular fields or a fixed list of performer kinds. Each
performer name is unique and cannot conflict with a procedure or interface
name. A performer describes who or what is designated to carry out an activity
in the written method; it is not evidence that the activity happened.

A paired stage may set a default with `stage name by performer-name from
state [ ... ]`. A state-changing call may override it with `do procedure-name
by performer-name with [ ... ] into location`, or `do procedure-name by
performer-name into location` when there are no inputs. Every call in a paired
stage must resolve to a declared performer, either its own or the stage
default. A stage without calls may omit `by`. The closing `end stage` does
not name a performer because it only declares the resulting state. The simple
`stage name` header does not accept `by`.

## Location-based calls

```text
to calculate-period :duration :count [output :duration / :count]

performer researcher [kind = "human" role = "scientist"]

stage Analyze by researcher from state [
  information = [elapsed = unknown swing-count = 10]
]
do calculate-period with [
  duration at information.elapsed
  count at information.swing-count
] into information.period
end stage with state [
  information = [elapsed = unknown swing-count = 10 period = unknown]
]
```

Each name before `at` matches one input declared by the procedure, without
the definition-only colon. Mapping order does not matter. `with [ ... ]` is
required when the procedure has inputs; for a procedure without inputs use
`do name into information.result`. Every paired-stage call has an `into`
location. A procedure called this way must return with `output` on every path
that can finish normally. An imported procedure uses the same form with its
qualified name, such as `timing.calculate-period`.

A location begins with one of the three set names and has at least one field.
An input location must exist when the call is reached; `unknown` means present
but unspecified, not absent. A return location must have an existing parent.
Its final field may already exist or be new. Only a location named by `into`,
or fields within a record returned to it, can change through a call, including
when the location is also an input. A procedure can return a record to change
several fields under one named return location.
Calls inside a paired stage take scientific inputs from state locations, not
from literals or detached local names. Locally assigned values are restricted to
integer counters or positions; `for each` there likewise needs integer
positions. A value intended as a scientific input must be placed in state.
The reserved `.count` property of a list in state can be read as an input
location, such as `information.measurements.count`. It can also supply an
integer counter or range bound. It is computed from the list rather than
stored as another state field, and cannot be an `into` location or the
target of a resource read.
An assignment from a declared [data source](resources.md) can also
change a state field. It needs an existing parent in state; an assignment to a
resource path declares an outbound transfer and does not change stage state.

## Reader constraints

The reader rejects a paired stage if its boundaries are incomplete, if its
sets or paths are malformed, or if a call names an unknown procedure. Every
`by` name must identify a declared performer object; every state-changing
call must have an explicit or inherited performer. Every
declared input must have exactly one mapping; duplicate, missing, and extra
mappings are errors. Each mapped input path must be available at the call,
including across earlier branches. A call without a guaranteed return or
without an existing parent for its `into` path is an error.

Every path guaranteed to be available after the stage body must appear in the
closing state. A closing field without a corresponding entry field needs an
explicit return or resource read that guarantees it on every path. An entry field cannot
silently change or disappear. A return or resource read to that field or its containing record
can account for a change. A return confined to an unresolved branch cannot
guarantee a new closing field.

These checks concern names, locations, and declared flow. They do not verify
that a procedure ran, that a declared value is scientifically suitable, or
that an environment existed in a particular run. A one-based position in a
list-valued location uses `.[position]`, such as `information.trials.[2]` or
`information.trials.[position]`. A named position must be a stage control
name. The selected positions must exist in the declared state.
