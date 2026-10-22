#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "propositions"]{Propositions}

A proposition is a named hypothesis, assumption, or conclusion. Its @tt{text}
is the author's statement. The language records relationships between
statements; it does not judge whether they are scientifically justified.

@verbatim|{
#lang sciencelogo
workflow "Does a smaller swing have a shorter period?"

hypothesis shorter-swing [text = "A shorter swing has a shorter period"]
assumption hand-timing [text = "Hand timing is comparable across trials"]
conclusion regular-period [text = "The observed period was nearly constant"]

stage Review
hypotheses.shorter-swing += conclusion not-supported [
  text = "The measurements did not support a shorter period"
]
}|

@tt{regular-period} is an independent conclusion: it is not linked to a stated
hypothesis. @tt{not-supported} is nested under @tt{shorter-swing}, so the
written method explicitly says which hypothesis it answers. A hypothesis may
remain without a conclusion, and a conclusion need not answer a hypothesis.

@section{Names and references}

The plural names @tt{hypotheses}, @tt{assumptions}, and @tt{conclusions}
access propositions at the root and at every nested level. The two conclusions
above have these paths:

@verbatim|{
conclusions.regular-period
hypotheses.shorter-swing.conclusions.not-supported
}|

Add @tt{.text} to read or update the wording. Each name is unique among
propositions of its type under the same parent. The same name may occur under
different parents because the full paths differ. Every proposition can hold
children of any of the three types.

@section{Adding and updating}

@tt{+=} adds a named child. Repeating its type and name at the same location
is an error; @tt{+=} never silently replaces an existing proposition.
Use @tt{=} to update a field of an existing proposition:

@verbatim|{
hypotheses.shorter-swing.conclusions.not-supported.text =
  "The revised finding"
}|

An independent conclusion can also be added later:

@verbatim|{
conclusions += conclusion regular-period [text = "The period was nearly constant"]
}|

Nested propositions can be written inside the original declaration. A
collection is a named record; an omitted collection starts empty.

@verbatim|{
hypothesis shorter-swing [
  text = "A shorter swing has a shorter period"
  conclusions = [not-supported = [text = "Measurements did not support it"]]
]
}|

The @hyperlink[(source-file-url "spec/propositions.md")]{proposition contract}
gives the complete rule and explains how a proposition can appear in a paired
stage's @tt{information} set.
