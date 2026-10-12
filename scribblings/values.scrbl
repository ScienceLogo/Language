#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "values"]{Values and expressions}

Values can be written directly or obtained from a name. Expressions can be
used in @tt{set}, procedure calls, @tt{output}, conditions, records, and ranges.
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
it with parentheses: @tt{[(x = y)]}.

@tt{item position of sequence} reads one list element. Positions start at
@tt{1}, not @tt{0}, and the position must be an exact positive integer within
the list. For nested lists, repeat @tt{item}: @tt{item 2 of item 1 of grid}
reads the second value of the first row. @tt{item} requires a list; use
@tt{field of record} for named fields.

@section{Records and fields}

Brackets whose first entry is @tt{name = value} make a record with named
fields. Field names are unquoted and distinct within one record:

@verbatim|{
set trial to [
  duration = 2
  unit = "seconds"
]
print unit of trial
}|

@tt{field of record} reads a field. It is an error if the record lacks that
field. Field order does not affect record equality. Brackets without an
initial @tt{name = value} make a list instead.

@tt{record but [field = value ...]} makes a copy with the listed changes;
the original remains unchanged. @tt{record but []} makes an identical copy.
The left side can also be a record interface; its defaults are applied to a
new record, and every required field must be supplied. See
@secref["interfaces"] for interface declarations.

@verbatim|{
set trial to [duration = 2 unit = "seconds"]
set revised to trial but [unit = "minutes"]
}|

After these lines, @tt{trial} still has @tt{unit = "seconds"}.

@section{Numeric ranges}

@tt{range start to end step increment} makes an ordered list of exact numbers.
The end is included only when a step lands on it. The step must be nonzero and
move toward the end. Bounds and step can be expressions:

@verbatim|{
set lengths to range 0.25 to 1 step 0.25
for each length in lengths [print length]
}|

One named range can be reused in several loops. Range values may start at
zero; the one-based rule applies only to list positions.

@section{Operators and conditions}

Arithmetic uses @tt{+}, @tt{-}, @tt{*}, and @tt{/} on exact numbers. Division
by zero is an error. A quotient without a finite decimal form is displayed
as a fraction. Comparisons use @tt{=}, @tt{!=}, @tt{<}, @tt{<=}, @tt{>}, and
@tt{>=}; ordered comparisons need numbers. Combine comparisons with
@tt{and} or @tt{or} rather than chaining them.

@tt{not}, @tt{and}, @tt{or}, and @tt{xor} operate on Boolean values.
@tt{false and unknown} is @tt{false}; @tt{true or unknown} is @tt{true}.
Other uses of @tt{unknown} in a condition can remain undetermined. An
undetermined or nonboolean condition stops execution with an explicit error.

From strongest to weakest, the reader groups operations in this order:

@(tabular #:style 'boxed
  (list
   (list (bold "Order") (bold "Operations"))
   (list "1" "Parentheses")
   (list "2" (tt "field of value; item position of sequence"))
   (list "3" (tt "but"))
   (list "4" (tt "unary -"))
   (list "5" (tt "* /"))
   (list "6" (tt "+ -"))
   (list "7" (tt "= != < <= > >="))
   (list "8" (tt "not"))
   (list "9" (tt "and"))
   (list "10" (tt "xor"))
   (list "11" (tt "or"))))

Operations at the same level associate left to right. Use parentheses when
the intended grouping is not immediately clear. For example,
@tt{do add 1 + 2 (3 * 4) as total} passes two expressions to @tt{add}.
