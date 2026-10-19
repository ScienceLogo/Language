#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "uncertainty"]{Uncertainty descriptions}

@tt{u} attaches a description of uncertainty to a value. It does not calculate
uncertainty or say that the description is scientifically adequate.

@verbatim|{
#lang sciencelogo
workflow "Time a pendulum"
period = 2.01 u [
  declared = [
    timing-resolution = [type = "epistemic" estimate = 0.02 unit = "s"]
    trial-spread = [type = "aleatory" estimate = unknown]
  ]
  omitted = [reaction-delay = [reason = "not estimated"]]
]
print period
print period.u.declared.timing-resolution.estimate
}|

The first @tt{print} shows @tt{2.01}. The second shows @tt{0.02}. The value
and its description remain separate to read: @tt{period} is the value, and
@tt{period.u} is its uncertainty record. @tt{u} is a reserved word. It can
follow any value expression; use parentheses to qualify the entire expression,
as in @tt{(duration / swings) u [ ... ]}.

@section{Named sources}

The @tt{u} record accepts only @tt{declared} and @tt{omitted} at its top level.
Both are records of named sources. Each source is a record with freely chosen
fields. An absent collection or @tt{[]} is empty. For example,
@tt{value u []} explicitly records no sources in either collection. It does
not mean zero uncertainty. A value with no @tt{u} has no attached description;
reading its @tt{.u} path is an error.

Put a considered source under @tt{declared}, even when its magnitude is
@tt{unknown} or judged negligible. Put a known source that is left out under
@tt{omitted}, and describe why when useful. The language does not require a
particular estimate, unit, or reason field.

@tt{type} is an ordinary, optional source field. It can distinguish
@tt{"aleatory"} from @tt{"epistemic"}, use another label, or hold more than
one label, such as @tt{type = ["aleatory" "epistemic"]}. These words are not
language keywords. A library can define a more specific vocabulary for a
particular method.

@section{Reading and revising}

Read a source through its name, such as
@tt{period.u.omitted.reaction-delay.reason}. A direct copy such as
@tt{other-period = period} keeps the attached description. Later edits to one
name do not change the copy.

@tt{period.u.declared.timing-resolution.estimate = 0.03} revises a field in
the description. @tt{period.u = [declared = [ ... ]]} replaces the description
on an already qualified value. Assigning a new plain value to @tt{period}
replaces both the old value and its attachment; write @tt{u [ ... ]} again if
the new value has a description. @tt{+=} is rejected on a qualified value.

Arithmetic and comparisons use the underlying value. Arithmetic does not
calculate or carry uncertainty forward, so describe uncertainty on a derived
result explicitly, for example @tt{result = (period / 2) u [ ... ]}. Applications
can inspect the written description to assess uncertainty by methods they
define. See the @hyperlink[(source-file-url "spec/uncertainty.md")]{compact
uncertainty contract} for the complete reader and update rules.
