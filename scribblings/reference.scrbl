#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "reference"]{Syntax}

This section documents the forms implemented by @tt{#lang sciencelogo} today.
Read @secref["getting-started"] for a first example, then use the topic pages
below as a language reference. The broader proposals in
@hyperlink[(source-directory-url "spec")]{the design specifications} are not
necessarily executable syntax.

@section{How to read the forms}

In a form such as @tt{to name :input [ ... ]}, command words such as @tt{to}
are written literally; @tt{name}, @tt{input}, and @tt{...} stand for content
you supply. Square brackets shown in a form are literal ScienceLogo
brackets. Quoted text is a text value. Commands may share a line or use
separate lines.

@section{Names and labels}

Names are case-sensitive. The table gives the project's spelling convention.
It is guidance for readable workflows; the reader does not enforce letter
case or the suggested word separator.

@(tabular #:style 'boxed
  (list
   (list (bold "What is named") (bold "Preferred form") (bold "Example"))
   (list "Library and repository" "Lowercase words joined by hyphens"
         (tt "pendulum-tools"))
   (list "Import or implementation alias" "Lowercase words joined by hyphens"
         (tt "timing-tools"))
   (list "Procedure" "Lowercase words joined by hyphens"
         (tt "estimate-period"))
   (list "Input" "Lowercase words joined by hyphens, preceded by : in code"
         (tt ":swing-count"))
   (list "Value, call result, or loop name" "Lowercase words joined by hyphens"
         (tt "trial-duration"))
   (list "Record field or required part" "Lowercase words joined by hyphens"
         (tt "mean-period"))
   (list "Interface" "First letter capitalized; later words lowercase and joined by hyphens"
         (tt "Timed-observation"))
   (list "Workflow or stage title" "Readable quoted text"
         (tt "\"Measure the pendulum\""))
   (list "Source file or directory" "Lowercase words joined by hyphens"
         (tt "methods/estimate-period.rkt"))))

An interface is declared with a quoted name, as in
@tt{interface "Timed-observation" [ ... ]}, and referred to without quotes as
@tt{Timed-observation}. An imported interface is @tt{alias.Timed-observation};
an imported procedure is @tt{alias.estimate-period}. A @tt{library} name is
display text: imports use its Git URL and the chosen alias, not that name.
Workflow and stage titles are display text; a @tt{must stages in order} check
uses the stage title exactly.

The reader rejects reserved command words as most user names, and rejects a
dot inside a procedure definition, import alias, or record interface name.
Dots qualify imported names and separate fields in stage state locations.
A name used as a word has no spaces;
quoted workflow and stage titles can contain spaces. Procedure names must be
distinct; interface names must be distinct from each other and from procedures;
stage names must be distinct across the assembled workflow. Each procedure has
distinct input names, and record fields are distinct within a record.
@secref["procedures"] explains local value scope and result names.

@section{Source files and composition}

Every ScienceLogo source file begins with @tt{#lang sciencelogo}. The entry
workflow is the file to run or assess. Its optional @tt{workflow "title"} is
the first form and labels the whole method without enclosing it in brackets.
Definitions may appear after their uses.

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "Where it belongs") (bold "Purpose"))
   (list (tt "workflow \"title\"") "First form of an entry workflow"
         "Names the method; at most one per file")
   (list (tt "library \"name\" [ ... ]") (tt "library.rkt") "Declares reusable procedures and record interfaces")
   (list (tt "import \"Git URL\" at \"tag\" as alias")
         "After a workflow title, before method forms; or directly in a library"
         "Loads a pinned library")
   (list (tt "include \"relative/path.rkt\"")
         "Top level of a workflow or library file"
         "Loads another file from the same repository")
   (list (tt "interface \"name\" [ ... ]")
         "Top level of a workflow or library, or alone in a file"
         "Declares record fields or workflow requirements")))

A library import selects a tag or full commit ID on its @tt{main} branch.
@secref["libraries"] gives the repository layout and dependency rules.
@secref["interfaces"] explains the two interface forms. Workflow files may
contain top-level commands, procedures, stages, record interfaces, obligations,
and includes. A library file may contain imports, includes, procedures, and
record interfaces; it has no top-level executable commands.

@subsection{Split a workflow across files}

Each @tt{include} path starts at the directory of the file containing it.
An included workflow file has no workflow title or import and can include more
files. For example, these three paths are in one Git repository:

@tt{method.rkt}:

@verbatim|{
#lang sciencelogo
workflow "Pendulum trial"
include "methods/period.rkt"
do period 20 10 as seconds-per-swing
print seconds-per-swing
}|

@tt{methods/period.rkt}:

@verbatim|{
#lang sciencelogo
include "../shared/divide.rkt"
to period :seconds :swings [
  do divide :seconds :swings as result
  output result
]
}|

@tt{shared/divide.rkt}:

@verbatim|{
#lang sciencelogo
to divide :total :count [output :total / :count]
}|

The reader assembles and validates the workflow before running it. Includes
must stay inside the repository. Missing files, duplicate includes, and cycles
are errors.

@section{Where to find each form}

@(tabular #:style 'boxed
  (list
   (list (bold "Topic") (bold "Forms covered"))
   (list (secref "values")
         (tt "numbers, text, true, false, unknown, lists, records"))
   (list (secref "values")
         (tt "range, item, of, but, arithmetic, comparisons, not, and, xor, or"))
   (list (secref "procedures")
         (tt "to, :input, do, as, output, set, print, stage, state, at, into"))
   (list (secref "procedures")
         (tt "repeat, until, for each, while, if, else if, else"))
   (list (secref "libraries")
         (tt "library, import, include"))
   (list (secref "interfaces")
         (tt "interface, version, extends, require, affects"))
   (list (secref "assessment")
         (tt "implements, provide, must do, must stages in order, must record implement"))))

@section{Comments and whitespace}

@tt{;} begins a line comment. @tt{#|} and @tt{|#} enclose a block comment;
block comments can nest. Whitespace is flexible, and empty blocks are allowed.
Parentheses group value expressions; brackets delimit blocks, lists, and
named-field records.

@section{What the reader checks}

Before running a workflow, the reader rejects malformed brackets, unsupported
commands, duplicate names, unknown procedures or values, wrong input counts,
a requested result from a procedure without @tt{output}, recursive procedure
calls, invalid interface inheritance, and misplaced file-level forms.
For state stages it also checks named input locations, compulsory return
locations, and the declared exit state. A state stage is read and checked but
its body is not executed by the current interpreter.
Structural obligations are assessed separately; a successful read does not
establish that scientific work occurred.
