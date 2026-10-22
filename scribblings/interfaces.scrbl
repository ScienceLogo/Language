#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "interfaces"]{Records and interfaces}

An interface describes the fields of a structured data object, called a
record, or the named parts a workflow may provide. Both use @tt{must [...]}
to identify required entries. A record check treats the entries as fields;
a workflow implementation declaration treats them as named workflow parts.
The reader accepts @tt{must [...]} in workflows, libraries, and separate
interface files. @secref["assessment"] explains the current structural checks.

@section{Required entries, defaults, and optional entries}

Present required entries together inside @tt{must [...]}, including entries
with defaults:

@verbatim|{
interface Timing [
  must [duration unit = "seconds"]
  notes
]
}|

@tt{duration} and @tt{unit} must both be present. When constructing a record,
supply @tt{duration}; the interface supplies @tt{"seconds"} for @tt{unit}
unless another value is provided. @tt{notes} may be absent.
The concrete default makes @tt{unit} a text field; @tt{"minutes"} is an
allowed replacement.
Required fields reject @tt{unknown} by default, including overrides of a
supplied default.

@(tabular #:style 'boxed
  (list
   (list (bold "Entry") (bold "Meaning"))
   (list (tt "must [duration unit]") "Both fields are required; neither has a default")
   (list (tt "must [duration unit = \"seconds\"]")
         "Both fields are required; unit has an overridable default")
   (list (tt "notes") "Optional; may be absent")
   (list (tt "notes is text") "Optional; checks supplied values as text")
   (list (tt "must [notes is text]") "Required; checks the supplied value as text")))

@subsection{Value kinds and unknown defaults}

An interface can require a @tt{number}, @tt{text}, @tt{boolean}, @tt{list},
or @tt{record}. A record is an object with named fields, such as
@tt{[period = 2 unit = "seconds"]}.

A concrete default also declares the field's kind. Use these forms:

@(tabular #:style 'boxed
  (list
   (list (bold "Declaration") (bold "Meaning"))
   (list (tt "must [period is number]") "Number required; no default")
   (list (tt "must [period = 2]") "Number required; default 2")
   (list (tt "must [period = unknown number]") "Number or explicit unknown; default unknown")
   (list (tt "must [timing = unknown Timing]") "Object matching Timing or explicit unknown; default unknown")
   (list (tt "must [period = unknown]") "No kind restriction; default unknown")))

The suffix after @tt{unknown} can use any of the five kinds or a declared
interface reference. For example,
@tt{must [measurements = unknown list]} permits a list or unknown.
A concrete list or record default constrains the outer kind; requirements
on its items or fields are declared separately. An attached @tt{u}
description does not change the underlying kind.

The field remains required. Construction fills an omitted default; checking
an existing record leaves it unchanged and still reports an absent field.
The permission follows the field through inheritance and library imports.
Redeclaring a field replaces its default, kind, and permission.
The @hyperlink[(source-file-url "examples/unknown-fields.rkt")]{runnable example}
shows a supplied period and a period explicitly allowed to be unknown.
The @hyperlink[(source-file-url "examples/value-kinds.rkt")]{value-kind example}
uses a numeric requirement for measured periods and an unknown numeric
default for planned periods.

Kind checks apply during construction and interface checks. A later value
update can be checked against the interface again. If a check cannot
establish the default's kind or the supplied value, it remains undetermined.
Ordinary variables do not acquire permanent kind restrictions.

@tt{value is kind} also works in expressions, such as
@tt{if period is number [...]}. On a known value it returns true or false;
on @tt{unknown} it remains unknown. A permitted unknown therefore leaves an
additional @tt{period is number} condition undetermined. The declaration
@tt{period = unknown number} directly allows that unknown field value.

A required list or record can contain unknown entries; requirements on
those entries are checked separately. Optional fields can still be absent
or contain @tt{unknown}. A permitted unknown value does not establish an
additional condition such as @tt{period > 0}; that condition remains
undetermined. A value the structural checker cannot resolve is also
undetermined, rather than being treated as an explicitly supplied @tt{unknown}.
Equality can directly test the explicit marker: @tt{period == unknown}
is true when @tt{period} contains @tt{unknown}; @tt{period != unknown}
tests the opposite. These expressions also work in interface conditions.
They do not replace the field's declaration of permitted values.

@tt{must} applies to every entry inside its brackets, whether they share a
line or use separate lines. A field with a default is compulsory even if it
is written outside @tt{must [...]}; grouping it inside makes that meaning
explicit and is the presentation used in this manual. Only an entry with
neither @tt{must} nor a default is optional. These rules are shared by data
interfaces and interfaces describing workflow parts. The
@hyperlink[(source-file-url "spec/interfaces.md")]{interface specification}
records the syntax and reader status.

@subsection{Reusing an interface for a field}

Use an interface name after @tt{is} to check the fields of a nested object:

@verbatim|{
interface Timing [
  must [period is number unit = "seconds"]
]

interface Experiment [
  must [timing is Timing]
]

timing = Timing.[period = 2]
experiment = Experiment.[timing = timing]
experiment implement Experiment
}|

The @tt{timing} field is required and must satisfy @tt{Timing}, including
its required fields, value conditions, and any nested or inherited
requirements. Extra fields are allowed. The nested object can have been
created directly with named fields; it need not have been constructed
from @tt{Timing}.

The test supplies no default and does not change its operand.
@tt{Timing.[period = 2]} inserts the default unit during construction.
By contrast, @tt{[period = 2] is Timing} is @tt{false}, because the required
@tt{unit} field is missing. @tt{[period = 2 unit = "minutes"] is Timing}
is @tt{true}: @tt{"seconds"} is an overridable default.

The same test works in expressions, such as @tt{if timing is Timing [...]},
and in conditional or per-item interface requirements. The target may be
defined later, loaded through @tt{include}, imported as
@tt{timing-tools.Timing}, or be a named nested group such as
@tt{Protocol.documentation}. A misspelled target is a reader error.

An unknown whole object gives @tt{unknown}. A missing required field, a
wrong value kind, or a false requirement gives @tt{false}. If no failure
is established but some checks remain unresolved, the answer is
@tt{unknown}. The target interface's existing unknown permissions apply
to its fields. Recursive interfaces can describe finite nested objects;
a circular test with no independent answer remains undetermined.

The @hyperlink[(source-file-url "examples/nested-interfaces.rkt")]{runnable example}
constructs a timing object and reuses its interface in an experiment.

@subsection{Unknown defaults with named interfaces}

Use @tt{field = unknown Interface} to supply and permit an unknown value
while checking supplied objects against an interface:

@verbatim|{
interface Timing [
  must [period is number unit = "seconds"]
]

interface Experiment [
  must [timing = unknown Timing]
]

experiment = Experiment.[]
experiment.timing = Timing.[period = 2]
experiment implement Experiment
}|

The @tt{timing} field is compulsory. Construction supplies @tt{unknown}
when it is omitted. An existing record must contain the field, and its
value must be either @tt{unknown} or an object satisfying @tt{Timing}.
The target interface's own field and value rules apply to supplied objects.
Checking an object does not insert its missing defaults: supplying
@tt{[period = 2]} fails this interface because @tt{unit} is absent.

The target may be declared later, included, imported as
@tt{timing-tools.Timing}, or name a nested group such as
@tt{Protocol.timing}. Its name is unquoted. A following bare word is treated
as a named suffix when it identifies a declared interface. Other names
retain their ordinary field meaning. To declare a separate field with the
same name as an interface after an unknown default, use a separate
@tt{must [...]} group or put that field earlier.

A further condition keeps its own meaning. For example, adding
@tt{must [timing is Timing]} leaves an explicitly unknown timing
undetermined, even though its default declaration permits unknown.
See the @hyperlink[(source-file-url "examples/interface-defaults.rkt")]{runnable example}.

@subsection{Constraints on optional fields}

Outside @tt{must [...]}, @tt{field is kind} leaves the field optional:

@verbatim|{
interface Timing [
  must [period is number]
  notes is text
]

trial = Timing.[period = 2]
trial.notes = "Timed by hand"
trial implement Timing
}|

The constructor leaves @tt{notes} absent until it is supplied. Once present,
its value is checked as text. A number in @tt{notes} violates the constraint.
An optional constraint supplies no default. Fields with defaults remain
compulsory under the ordinary declaration rule.

The target can also be a named interface: @tt{review is Review} checks a
supplied review object against @tt{Review}. Local, included, imported, and
nested interface references use the same rules as required @tt{is} tests.
The optional form works in nested groups, conditional branches, and
@tt{for each} declarations, such as @tt{item.notes is text}. Inheritance
preserves the constraint; redeclaring the field replaces its declaration.

An absent field is skipped. A supplied @tt{unknown}, or a value the checker
cannot establish, leaves the constraint undetermined. A constructor reports
that unresolved check. A plain record can retain the value for inspection.
An unconstrained optional field, written simply @tt{notes}, can still
contain @tt{unknown} without a kind check.

The @hyperlink[(source-file-url "examples/optional-fields.rkt")]{runnable example}
uses an optional text field and an optional object constrained by an interface.

@section{Requirements on values}

A @tt{must [...]} group can mix conditions and required entries:

@verbatim|{
interface Timing-trial [
  must [swing-count > 10 swing-height unit == "seconds"]
]
}|

This requires @tt{swing-count} to be greater than @tt{10},
@tt{swing-height} to be present, and @tt{unit} to equal @tt{"seconds"}.
The entries referenced by a condition must be present and reject @tt{unknown}
by default. @tt{swing-height = unknown} therefore violates this interface.
Declare @tt{must [swing-height = unknown]} to permit that value and provide
it as a default. A comparison using a permitted unknown can remain undetermined.

Use the existing arithmetic, comparison, and Boolean expressions:

@verbatim|{
must [swing-count > 10 and swing-count < 100 swing-height]
}|

The first expression is one condition; @tt{swing-height} is the next entry.
Names refer to entries of the surrounding interface part. Existing entries
and defaults are reused; conditions do not require duplicate declarations.
Dotted paths access nested values. Conditions can be nested under @tt{if},
and inheritance preserves them.

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "Meaning"))
   (list (tt "must [unit = \"seconds\"]") "Supplies an overridable default")
   (list (tt "must [unit == \"seconds\"]") "Requires that exact value; supplies no default")))

@tt{==} is the equality comparison throughout the language. Assignments,
record entries, and defaults use @tt{=}. Construction fills applicable
defaults, then checks applicable requirements. A false requirement fails;
an unresolved value requirement is reported as undetermined. The
@hyperlink[(source-file-url "examples/value-requirements.rkt")]{runnable value-requirement example}
constructs and checks a timing trial. @secref["assessment"] describes the
current structural checker.

Use @tt{in} to require one of several allowed values:

@verbatim|{
interface Timing [
  must [method in ["manual" "video"]]
]
}|

This requires @tt{method} to equal @tt{"manual"} or @tt{"video"}; it supplies
no default. A named list is also possible. As with other interface
expressions, its name refers to a field of the surrounding interface part:

@verbatim|{
must [methods = ["manual" "video"] method in methods]
}|

Construction supplies the @tt{methods} default; checking an existing record
requires that field to be present. Membership uses the same rules in
conditional branches, nested parts, and @tt{for each} requirements.
Required fields still reject @tt{unknown} unless explicitly permitted.
The marker can match a list item: @tt{unknown in [unknown]} is true, while
@tt{unknown in ["manual" "video"]} is false. An unknown list or values the
checker cannot establish can leave membership undetermined.

The same @tt{in} checks field presence when its right operand is a record:

@verbatim|{
interface Trial [
  details [notes]
  if notes in details [must [reviewer]]
]
}|

Here @tt{notes} is an unquoted field name in @tt{details}, not a separate
entry in @tt{Trial}. The optional field stays optional. If it is present,
even with value @tt{unknown}, the branch requires @tt{reviewer}.
@tt{must [notes in details]} instead requires that field to be present;
the presence test alone does not constrain its value.
@secref["values"] gives the expression rules.

@section{Declaration forms}

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "Purpose"))
   (list (tt "interface Name [must [required-field defaulted-field = value] optional-field]")
         "Declare required fields, their defaults, and optional fields")
   (list (tt "extends Parent")
         "Inherit fields from a local or imported record interface")
   (list (tt "field is kind-or-interface")
         "Outside must, check the field only when supplied")
   (list (tt "interface Name [version \"...\" must [name ...] optional-name affects source target ...]")
         "Declare required and optional workflow parts in a separate file")))

An @tt{interface} may have one nonempty @tt{version} line or omit it.
Local and imported interfaces may have @tt{extends} lines. Interfaces
describing workflow parts use the same required-entry brackets and bare
optional names. An @tt{affects source target} line links two required entries.
Separate interface files cannot extend local interfaces.

@section{Nested protocol parts}

A name followed by brackets declares a part containing its own requirements.
The @hyperlink[(source-file-url "examples/interfaces/pendulum-protocol.rkt")]{pendulum protocol example}
uses the same @tt{must [...]} rule at each level:

@verbatim|{
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
}|

@tt{measurement} and @tt{documentation} are required. Within
@tt{documentation}, @tt{uncertainty} is required and @tt{notes} is optional.
@tt{additional-measurements} is optional at the protocol level. A default
on an entry makes that entry compulsory within its parent, as with other
interface entries.

Dots reference the hierarchy: @tt{Pendulum-protocol.documentation.uncertainty}
identifies the uncertainty part. Names are unique within their parent;
different parts can use the same child name. The interface version covers
the full hierarchy.

A mapping to a parent also claims its required children. For example,
@tt{"Report"} identifies a stage declared in the workflow:

@verbatim|{
Report implement Pendulum-protocol.documentation
}|

This also claims @tt{documentation.uncertainty}. The child can instead be
referenced directly:

@verbatim|{
information.period.u implement Pendulum-protocol.documentation.uncertainty
}|

The second line belongs inside a state stage where @tt{information.period.u}
is available. It maps that uncertainty description to the specific requirement.
Mapping one child does not claim its siblings. Optional nested parts
remain optional when their parent is mapped. When an optional part is
mapped, its own required children apply. These declarations identify work
and data for inspection; they do not establish scientific conformity.

Use @tt{implement} directly, without a @tt{must} prefix. An unquoted stage name,
a procedure name, or a value path can appear on its left. On its right,
use the interface name and dotted path, including the existing library alias
when imported, such as @tt{prot.Pendulum-protocol.documentation}. A stage or
procedure may reference the whole interface. Several workflow parts can
map to one requirement, and one part can map to several requirements.
See @secref["assessment"] for a complete example and the checks available.

Named blocks also describe nested data fields. A nested part can be used
with the existing construction and record-check forms:

@verbatim|{
details = Pendulum-protocol.documentation.[uncertainty = [estimate = unknown]]
details implement Pendulum-protocol.documentation
}|

The reader preserves the dotted names, each entry's requiredness, and parent
links for tools inspecting the protocol. @tt{version} and @tt{extends}
belong to the interface declaration; named parts contain entries and their
@tt{must [...]} groups. An @tt{affects} link inside a part uses names relative
to that part.

@section{Conditional requirements}

Interfaces use the same @tt{if}, @tt{else if}, and @tt{else} forms as
ordinary statements. The
@hyperlink[(source-file-url "examples/conditional-interface.rkt")]{conditional interface example}
declares different requirements for three timing methods:

@verbatim|{
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
}|

@(tabular #:style 'boxed
  (list
   (list (bold "Timing method") (bold "Required entries"))
   (list (tt "\"automatic\"") "method, instrument, and unit (default: seconds)")
   (list (tt "\"video\"") "method and frame-rate")
   (list "Any other known value" "method and observer")))

Each condition uses the existing comparisons and Boolean operators.
@tt{else if} and @tt{else} apply when all earlier conditions are false;
either can be omitted. There is no separate @tt{elseif} form.
Within a named part, names refer to that part's entries. Dotted paths keep
their usual meaning. Conditions may refer to entries declared later or
inherited from another interface.

The normal entry rules apply inside each branch. Defaults apply only in an
active branch. Optional entries stay outside @tt{must [...]}, without a
default. Entries in an inactive branch may still be supplied as additional
fields. Entry names remain unique in their surrounding named part,
including across conditional branches. Further conditionals can be nested;
@tt{version} and @tt{extends} stay at interface level.

Construct records with the existing syntax:

@verbatim|{
automatic = Timing-protocol.[method = "automatic" instrument = "timer-1"]
video = Timing-protocol.[method = "video" frame-rate = 25]
manual = Timing-protocol.[method = "manual" observer = "researcher"]
}|

@tt{automatic.unit} is @tt{"seconds"}. The other records receive no unit
default from the inactive branch. Construction checks the requirements of
the applicable branch. To allow an unknown method, declare
@tt{must [method = unknown]}. If an omitted required field depends on an unknown
condition, construction reports an undetermined conditional requirement.
Plain records can retain unknown values for inspection; the structural
check reports unresolved requirements as @tt{undetermined}.
An equality comparison with an explicit unknown is resolved: for example,
@tt{method == "automatic"} is false when @tt{method} is @tt{unknown}.
Use @tt{if method == unknown [...]} to state requirements for that case.
The @hyperlink[(source-file-url "examples/unknown-equality.rkt")]{unknown-equality example}
requires an explanation when a period is unknown and a positive number otherwise.

For a workflow, the existing @tt{implement} form connects a value to the
interface entry used by a condition:

@verbatim|{
information.timing-method implement Timing-protocol.method
}|

The reader preserves the condition and mappings. The current mapping checker
resolves literal conditions; conditions depending on mapped workflow values
remain undetermined when required mappings are absent. Other applications
can inspect those values and conditions to assess conformity.

@section[#:tag "interface-list-requirements"]{Requirements for every item in a list}

Use @tt{for each} inside an interface to describe every item in a list:

@verbatim|{
interface Timing-series [
  must [measurements]

  for each measurement in measurements [
    must [measurement.period measurement.period.u]
  ]
]
}|

The interface requires a @tt{measurements} list. Each item must have a
@tt{period} field and an attached uncertainty description accessible through
@tt{period.u}. These are the requirements of this example protocol.
The block describes the items; it does not perform measurements.
The @hyperlink[(source-file-url "examples/list-requirements.rkt")]{runnable example}
constructs and checks a series with three measurements, including a minimum
count requirement.

The name @tt{measurement} refers to one item and is local to the block.
Use its dotted paths for entries and the existing expressions for conditions:

@verbatim|{
for each measurement in measurements [
  must [measurement.swing-count > 10 measurement.unit == "seconds"]
]
}|

Entry declarations begin with the item name. They use the same required,
optional, and default rules as other interface entries.
Conditions may also read entries declared in the surrounding interface
part. @tt{if}, @tt{else if}, @tt{else}, and further @tt{for each} blocks
can appear inside the block. Nested loops can refer to their enclosing
item names. Scalar lists can use the item name directly, as in
@tt{for each count in counts [must [count > 10]]}.

To require a minimum number of measurements as well as their individual
fields, use the list's reserved @tt{.count} property:

@verbatim|{
interface Timing-series [
  must [measurements.count >= 3]

  for each measurement in measurements [
    must [measurement.period measurement.period.u]
  ]
]
}|

This requires at least three items. @tt{must [measurements.count == 3]}
requires exactly three. The count is computed from the list; it is not
a separate field the author supplies. An unknown item value still occupies
one position. An explicitly unknown list is rejected by default. Declare
@tt{must [measurements = unknown]} to permit it; its count requirement then
remains undetermined.

@(tabular #:style 'boxed
  (list
   (list (bold "Written collection") (bold "Check"))
   (list "Known list" "Checks every item; any known violation makes the requirement violated")
   (list (tt "[]") "Per-item requirements are satisfied; a separate minimum count can still be violated")
   (list (tt "unknown") "Rejected by default; unresolved checks are undetermined when the collection permits unknown")
   (list "Missing collection or a known value that is not a list" "Violated when the block applies")))

A missing item field identifies its position, such as
@tt{measurements.[2].period.u}. An unknown value can leave a condition
undetermined when the field permits @tt{unknown}. Required item fields
otherwise reject it by default.
The existence of @tt{period.u} does not establish the adequacy of the
uncertainty description.

Construction fills applicable defaults in referenced list items. For
example, @tt{must [measurement.unit = "seconds"]} supplies each item's unit
unless overridden. Checking an existing record leaves it unchanged.
The @hyperlink[(source-file-url "spec/interfaces.md")]{interface specification}
describes collection locations and default completion.
Inheritance and library imports preserve the whole declaration.
The workflow model retains the collection, local name, conditions, nesting,
and source locations for applications to inspect. A workflow mapping alone
does not establish the values of its list items.

@section{Record interfaces}

A data interface names fields. Required fields, including those with
defaults, must be present in the completed record. Optional fields may be
absent, and extra fields are allowed. The
@hyperlink[(source-file-url "examples/record-interface.rkt")]{timing record example}
is a runnable workflow:

@verbatim|{
#lang sciencelogo

workflow "Check timing records"
interface Timing [must [duration unit = "seconds"]]
trial = Timing.[duration = 2]
trial implement Timing
revised = trial.[unit = "minutes"]
revised implement Timing
revised implement "interfaces/timing.rkt"
}|

@tt{Timing.[duration = 2]} creates a record with @tt{unit = "seconds"}.
Construction fails if a required field remains absent after applying defaults.
On the right side of an
assignment, @tt{trial.[unit = "minutes"]} produces a modified value for
@tt{revised}; @tt{trial} retains its earlier value. The existing @tt{trial}
can also be updated:

@verbatim|{
trial += [unit = "minutes" note = "hand timed"]
trial.duration += 2
}|

After construction, @tt{+=} can replace @tt{unit}, add @tt{note}, or add to
the existing numeric @tt{duration}. Extra fields remain allowed.

A literal record can satisfy the same interface even when it was not
constructed from @tt{Timing}:

@verbatim|{
direct = [duration = 2 unit = "seconds"]
direct implement Timing
}|

@tt{duration = unknown} would violate this interface. Declaring
@tt{must [duration = unknown unit = "seconds"]} explicitly permits an unknown
duration and supplies it as a default. The permission does not establish
a scientific value for it.
The @tt{implement} check is declarative: it examines the written record shape and
does not run the workflow. A direct record assignment or a dotted update has
a known shape. A record returned by a procedure, or one possibly changed by
a conditional or loop, is reported as undetermined. The check itself is
described in @secref["assessment"].

The same interface can be a separate
@hyperlink[(source-file-url "examples/interfaces/timing.rkt")]{@tt{#lang sciencelogo} file}.
In this example, @tt{revised implement "interfaces/timing.rkt"} checks
against that file; the path
is relative to the workflow file. The assessor records the source revision
hash even when the optional @tt{version} is omitted. The standalone form
checks a record; local declarations supply a name usable in construction.
A stage or procedure reference uses the same @tt{implement} word to map
workflow parts. A value mapped to an interface or nested group is checked
for required fields; a value mapped to an individual requirement identifies
the data addressing that requirement.

@section{Extend and combine record interfaces}

@tt{extends Parent} inherits a record interface. Repeating it combines
several parents. The
@hyperlink[(source-file-url "examples/combined-interface.rkt")]{combined interface example}
runs and passes the assessor:

@verbatim|{
workflow "Describe a pendulum trial"
interface Timed-observation [
  extends Timing
  extends Location
  must [observation unit = "minutes"]
]
interface Timing [must [duration unit = "seconds"]]
interface Location [must [place]]

trial = Timed-observation.[
  duration = 2
  place = "lab"
  observation = "ten swings"
]
trial implement Timed-observation
trial implement Timing
trial implement Location
}|

The parent interfaces may be declared after the interface that extends them.
@tt{Timed-observation} requires @tt{duration}, @tt{place}, and @tt{observation};
its own @tt{unit = "minutes"} replaces the @tt{Timing} default. A child may
also replace an inherited default with a required field without a default,
written inside @tt{must [...]}. Identical field
declarations from different parents merge. If parents define the same field
differently, the child must declare that field explicitly to resolve the
conflict. Unknown parents and extension cycles are reader errors. Construction
checks all inherited required fields, and @tt{implement} can check a resulting
record against the combined interface or any of its parents by field presence.
The same check follows nested groups. Unknown nested contents are reported
as undetermined; an optional group that is absent remains optional.
If every required field has a default, @tt{Combined.[]} constructs a record
using those defaults.
An interface may also declare required nested fields, including defaults,
as @tt{must [clock.time clock.unit = "seconds"]}. These are paths through a
record, with the same dot meaning used to read and update its values.
An inherited interface may be declared later in the same workflow, in an
included workflow file, or imported from a library. Importing a library as
@tt{timing} makes its @tt{Timing} record interface available as
@tt{timing.Timing}; write @tt{extends timing.Timing} in a local interface and
@tt{trial implement timing.Timing} to check a record against it. A library
can itself extend an interface imported from another library. Its dependency
alias remains internal, so a workflow imports that dependency directly if it
needs to name the interface.

@section{Workflow-part interfaces}

A workflow-part interface uses the same declaration in a workflow, library,
or separate @tt{#lang sciencelogo} file.
Its @tt{must [...]} group names parts that must be provided. Bare names
outside that group name parts that may be provided. An omitted optional part is not a
missing requirement. @tt{affects source target} marks a possible downstream effect
if a required part is missing. A version line can identify the interface,
but the assessor does not compare versions.

The @hyperlink[(source-file-url "examples/meta-assessor/requirements/assessor.rkt")]{assessor interface}
is a separate @tt{#lang sciencelogo} file. It has one version and five required
parts:

@verbatim|{
#lang sciencelogo

interface Assessor-process [
  version "0.1"
  must [
    parse
    resolve-libraries
    check-interfaces
    trace-impacts
    report
  ]

  affects parse check-interfaces
  affects resolve-libraries check-interfaces
  affects check-interfaces trace-impacts
  affects trace-impacts report
]
}|

The @hyperlink[(source-file-url "examples/meta-assessor/method.rkt")]{example workflow}
that supplies these parts is explained in @secref["assessment"]. These five
parts belong to the example interface; they are not built-in ScienceLogo parts.

For example, an interface can require measurement and allow supplementary
notes:

@verbatim|{
interface Pendulum-recording [
  version "1"
  must [measurement]
  supplementary-notes
]
}|

A workflow may map a part to @tt{supplementary-notes}, but it
does not have to. The same required-entry rule applies when an interface
describes data fields: a bare name without a default is optional.
