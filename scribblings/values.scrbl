#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "values"]{Values and expressions}

Values can be written directly or obtained from a name. Expressions can be
used in assignments, procedure calls, @tt{output}, conditions, records, and ranges.
The @secref["reference"] page defines the naming convention.

@section{Direct values and names}

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "Meaning"))
   (list (tt "\"seconds\"") "Quoted text")
   (list (tt "2") "An exact number")
   (list (tt "0.25") "An exact decimal number")
   (list (tt "true") "Boolean true")
   (list (tt "false") "Boolean false")
   (list (tt "unknown") "An explicit value whose content is not known")
   (list (tt ":input") "A declared input inside its procedure")
   (list (tt "name") "A visible value, result, or record interface")))

Unquoted names refer to values; quoted text remains text. ScienceLogo keeps
decimal literals exact. @tt{unknown} is a value, so a record field containing
it is present even though its scientific value is unknown.

@section{Ordered lists and positions}

@tt{[1 2 3]} is an ordered list. Lists can contain other values and lists;
@tt{[[1 2] [3 4]]} is a list of rows. To put a comparison in a list, group
it with parentheses: @tt{[(x == y)]}.

@tt{sequence.[position]} reads one list element. Positions start at @tt{1},
and the position must be an exact positive integer within the list.
@tt{grid.[1].[2]} reads the second value of the first row. Several positions,
as in @tt{sequence.[1 3]}, select a new list in the stated order.

Use @tt{=} on an indexed target to replace an existing list entry. Use
@tt{+=} on the list itself to append one item:

@(tabular #:style 'boxed
  (list
   (list (bold "Operation") (bold "Form") (bold "Effect"))
   (list "Replace an entry" (tt "values.[2] = 3")
         "The second entry becomes 3; the list length stays the same")
   (list "Append an item" (tt "values += 3")
         "3 becomes a new last entry; the list length increases by one")))

@verbatim|{
values = [1 2]
values.[2] = 3         ; values is now [1 3]
values += 4            ; values is now [1 3 4]
values += [5 6]        ; values is now [1 3 4 [5 6]]
}|

The appended value is one complete item, even when it is a list or record.
To replace several existing positions together, use
@tt{values.[1 = 7 2 = 8]}. Lists remain lists from their first entry;
@tt{+=} does not convert a scalar into a list.

@tt{sequence.count} reports the number of items. @tt{.count} is a reserved,
read-only list property:

@verbatim|{
measurements = [2 unknown 2.1]
print measurements.count       ; 3
print [].count                 ; 0
}|

It counts positions, so unknown item values still count. An unknown list
has an unknown count. The property also works on nested lists, selected
lists, and ranges, such as @tt{grid.[1].count} or @tt{lengths.count}.
Use it in assignments, procedure inputs, arithmetic, loops, and conditions.
Changing a list changes its count automatically. Assigning to
@tt{measurements.count}, including with @tt{+=}, is an error.
@secref["interface-list-requirements"] shows how an interface can require
a minimum or exact count.

@section{Records and fields}

Brackets whose first entry is @tt{name = value} make a record with named
fields. Field names are unquoted and distinct within one record:

@verbatim|{
trial = [
  duration = 2
  unit = "seconds"
]
print trial.unit
}|

@tt{trial.unit} reads one named field. @tt{trial.[duration unit]} selects a
new record containing both named fields; it does not create local names.
It is an error to read a missing field. Field order does not affect record
equality. Brackets without an initial @tt{name = value} make a list instead.

A record may have an ordinary field named @tt{count}. For example,
@tt{trial = [count = 7]} makes @tt{trial.count} equal to @tt{7}, and
@tt{trial.count = 8} updates that field normally. The reserved list property
applies when the value before @tt{.count} is a list; it does not reserve
@tt{count} as a record field or variable name.

Data stored outside the workflow uses a declared @secref["resources"] instead of
an ordinary record path.
An attached @secref["uncertainty"] is read with @tt{value.u}; @tt{u} is not
an ordinary user field name.
In a record declaration, @tt{clock.time = "12:00"} creates nested fields;
it has the same shape as @tt{clock = [time = "12:00"]}.

@tt{trial.unit = "minutes"} updates one field. At command position,
@tt{trial.[unit = "minutes" duration = 3]} updates or adds several fields.
The equivalent update command @tt{trial += [unit = "minutes" duration = 3]}
also updates existing fields and adds missing ones. Its right side must be a
record written with named fields. The name on the left must already exist.
An earlier value assigned from @tt{trial} retains its earlier contents.
On the right side of an assignment, @tt{trial.[unit = "minutes"]} makes a
modified value for another name. An interface name can be used the same way
to construct a record with its defaults and required fields; see
@secref["interfaces"].

@verbatim|{
trial = [duration = 2 unit = "seconds"]
revised = trial.[unit = "minutes"]
trial += [unit = "minutes"]
trial.duration += 2
}|

Here @tt{revised} keeps its earlier contents after @tt{trial} changes.
On a numeric value, @tt{+=} adds the number on its right: the last line
changes @tt{trial.duration} from @tt{2} to @tt{4}. The numeric value must
already exist and both values must be exact numbers.
Nested fields use the same path, such as @tt{trial.clock.unit}.
@tt{trial.[clock.time = "12:00"]} updates that nested field while preserving
other fields of @tt{clock}. Missing containing fields are created as records;
an existing containing value must be a record.
@secref["propositions"] describes a separate
@tt{+=} rule for adding named propositions under another proposition.

@section{Numeric ranges}

@tt{range start to end step increment} makes an ordered list of exact numbers.
The end is included only when a step lands on it. The step must be nonzero and
move toward the end. Bounds and step can be expressions:

@verbatim|{
lengths = range 0.25 to 1 step 0.25
for each length in lengths [print length]
}|

One named range can be reused in several loops. Range values may start at
zero; the one-based rule applies only to list positions.

@section{Membership and field presence}

Use @tt{in} for both checks. The value on the right determines what is checked:

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "Meaning"))
   (list (tt "value in list") "Does the list contain an equal item?")
   (list (tt "field in record") "Does the record contain that named field?")))

@verbatim|{
trial = [period = unknown method = "manual"]
if period in trial [print "period is present"]
if not (notes in trial) [print "notes is absent"]
}|

For a record, the left word is an unquoted field name. It need not name a
variable, and a variable with the same name does not change which field is
checked. Presence gives @tt{true} even when the field's value is
@tt{unknown} or @tt{false}; a missing field gives @tt{false}.
Only the immediate fields are checked. Use a nested record on the right,
such as @tt{notes in trial.details}, to check a field inside it.
Quoted text and other value expressions are not record field selectors.

@tt{value in list} tests whether a value equals an item in a list:

@verbatim|{
methods = ["manual" "video"]
method = "manual"
accepted = method in methods
if accepted [print method]
}|

The right side can be a literal list, a named list, a nested list field,
or a range. With a list on the right, names on the left supply their stored
values. Membership compares whole items using
the same equality as @tt{==}; it does not search inside an item's fields
or nested lists. For example, @tt{1 in [[1 2]]} is @tt{false}.

A matching item returns @tt{true}; if every comparison is false, membership
returns @tt{false}. An empty list always gives @tt{false}. The explicit
@tt{unknown} marker is compared like other items: @tt{unknown in [unknown]}
is @tt{true}, while @tt{2 in [unknown 1]} is @tt{false}.
When the entire list or record is @tt{unknown}, the check remains @tt{unknown}.
A checker unable to establish an operand can also leave the result undetermined.
Any known right operand other than a list or record raises an error when run.

Membership works wherever expressions are accepted, including procedure
inputs and outputs, conditions, and interface requirements. Use
@tt{not (method in methods)} to negate it. It has the same precedence as
@tt{==}; comparisons cannot be chained. The
@hyperlink[(source-file-url "examples/list-membership.rkt")]{runnable example}
uses both a named list and an interface requirement. The
@hyperlink[(source-file-url "examples/field-presence.rkt")]{field-presence example}
shows both checks together.

@section{Kinds and interface tests}

@tt{value is kind} checks the outer kind of a value:

@verbatim|{
period = 2
numeric = period is number
if numeric [print period]
}|

The available kinds are @tt{number}, @tt{text}, @tt{boolean}, @tt{list},
and @tt{record}. A record is an object with named fields. These words name
kinds after @tt{is}; they can still be ordinary names elsewhere.
The @tt{is} operator is reserved and has comparison precedence.

A known value gives @tt{true} or @tt{false}; @tt{unknown is number} gives
@tt{unknown}. The test checks the outer value, so @tt{[unknown] is list}
is @tt{true}. An attached @tt{u} description does not change the kind.
Combine tests with @tt{and}, @tt{or}, and @tt{not}; comparisons cannot be
chained. These expressions also work in procedure inputs and outputs,
loops, and interface conditions.

The same @tt{is} accepts a declared interface name:

@verbatim|{
interface Timing [must [period is number unit = "seconds"]]
trial = [period = 2 unit = "seconds"]
if trial is Timing [print trial.period]
}|

This checks the interface's requirements against the supplied object.
It returns @tt{true} for a match, @tt{false} for an established mismatch,
and @tt{unknown} when the available values do not settle the check.
It does not insert defaults or change the object. Local and imported
interface names work here, including @tt{trial is timing-tools.Timing}.

@secref["interfaces"] explains how interface defaults declare kinds and how
@tt{period = unknown number} explicitly permits an unknown numeric field.
The corresponding @tt{timing = unknown Timing} supplies and permits unknown
while checking supplied objects against the named interface.

@section{Operators and conditions}

Arithmetic uses @tt{+}, @tt{-}, @tt{*}, and @tt{/} on exact numbers. Division
by zero is an error. A quotient without a finite decimal form is displayed
as a fraction. Comparisons use @tt{==}, @tt{!=}, @tt{<}, @tt{<=}, @tt{>},
@tt{>=}, and @tt{in}; ordered comparisons need numbers. Combine comparisons with
@tt{and} or @tt{or} rather than chaining them.
@tt{=} supplies values in assignments, record entries, and interface defaults;
it is not an equality comparison. For example, @tt{ready = count == 20}
assigns the result of a comparison to @tt{ready}.

@subsection{Equality and unknown}

@tt{==} and @tt{!=} compare @tt{unknown} as an explicit value:

@(tabular #:style 'boxed
  (list
   (list (bold "Expression") (bold "Result"))
   (list (tt "unknown == unknown") (tt "true"))
   (list (tt "unknown == 2") (tt "false"))
   (list (tt "2 != unknown") (tt "true"))
   (list (tt "[unknown] == [unknown]") (tt "true"))))

The same rule applies inside records and lists. Use the ordinary equality
operators to choose a branch:

@verbatim|{
period = unknown
if period == unknown [
  print "Period not yet known"
] else [
  print period
]
}|

The comparison tests the explicit marker. An absent field or a value the
checker cannot establish is not automatically an explicit @tt{unknown}.
Arithmetic, ordered comparisons, and kind tests using an unknown value can
still return @tt{unknown}. The
@hyperlink[(source-file-url "examples/unknown-equality.rkt")]{runnable example}
uses equality in conditional interface requirements.

@subsection{Boolean operators and precedence}

@tt{not}, @tt{and}, @tt{or}, and @tt{xor} operate on Boolean values.
@tt{false and unknown} is @tt{false}; @tt{true or unknown} is @tt{true}.
Other uses of @tt{unknown} in a condition can remain undetermined. An
undetermined or nonboolean condition stops execution with an explicit error.

From strongest to weakest, the reader groups operations in this order:

@(tabular #:style 'boxed
  (list
   (list (bold "Order") (bold "Operations"))
   (list "1" "Parentheses")
   (list "2" (tt ".field, .[ ... ], and u [ ... ]"))
   (list "3" (tt "unary -"))
   (list "4" (tt "* /"))
   (list "5" (tt "+ -"))
   (list "6" (tt "== != < <= > >= in is"))
   (list "7" (tt "not"))
   (list "8" (tt "and"))
   (list "9" (tt "xor"))
   (list "10" (tt "or"))))

Operations at the same level associate left to right. Use parentheses when
the intended grouping is not immediately clear. For example,
@tt{do add 1 + 2 (3 * 4) as total} passes two expressions to @tt{add}.
Every explicit parenthesis group remains in the parsed workflow, including
nested or redundant groups. Checks and evaluation respect those groups.
For example, @tt{((1 == 1)) == true} is valid and evaluates to @tt{true}.
