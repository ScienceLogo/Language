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
For lists, @tt{trials.[2] = value} replaces an existing position;
@tt{trials.[1 = first 2 = second]} replaces several positions.
@tt{trials += value} appends one item, even when @tt{value} is itself a list
or record. Lists remain lists from their first entry; @tt{+=} does not
convert a scalar into a list. @secref["propositions"] describes a separate
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

@section{Operators and conditions}

Arithmetic uses @tt{+}, @tt{-}, @tt{*}, and @tt{/} on exact numbers. Division
by zero is an error. A quotient without a finite decimal form is displayed
as a fraction. Comparisons use @tt{==}, @tt{!=}, @tt{<}, @tt{<=}, @tt{>}, and
@tt{>=}; ordered comparisons need numbers. Combine comparisons with
@tt{and} or @tt{or} rather than chaining them.
@tt{=} supplies values in assignments, record entries, and interface defaults;
it is not an equality comparison. For example, @tt{ready = count == 20}
assigns the result of a comparison to @tt{ready}.

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
   (list "6" (tt "== != < <= > >="))
   (list "7" (tt "not"))
   (list "8" (tt "and"))
   (list "9" (tt "xor"))
   (list "10" (tt "or"))))

Operations at the same level associate left to right. Use parentheses when
the intended grouping is not immediately clear. For example,
@tt{do add 1 + 2 (3 * 4) as total} passes two expressions to @tt{add}.
