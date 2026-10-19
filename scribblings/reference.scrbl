#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "reference"]{Syntax}

This page is the map of forms accepted by @tt{#lang sciencelogo}. Read
@secref["getting-started"] to learn the basic pattern; follow the links below
for each form's full rule. Most forms run. Paired stages and their location
calls are read and checked as a written method but are not executed. Design
sketches in the @hyperlink[(source-file-url "spec/README.md")]{specification
index} are marked separately and should not be treated as accepted syntax.

@section{How to read the forms}

In a form such as @tt{to name :input [ ... ]}, command words such as @tt{to}
are written literally; @tt{name}, @tt{input}, and @tt{...} stand for content
you supply. Square brackets shown in a form are literal ScienceLogo
brackets. Quoted text is a text value. Commands may share a line or use
separate lines.

At command position, @tt{name = value} assigns a value. In a condition,
@tt{=} compares values. Within a record or dotted update, it supplies a field
value; within an interface, it supplies a default. At command position,
@tt{name += [field = value]} updates or adds record fields, while
@tt{name.field += number} adds to an existing numeric field. On a list,
@tt{name += value} appends one item. See
@secref["procedures"] for scope.

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
   (list "Performer" "Lowercase words joined by hyphens"
         (tt "researcher"))
   (list "Resource" "Lowercase words joined by hyphens"
         (tt "timing-data"))
   (list "Proposition" "Lowercase words joined by hyphens"
         (tt "swing-period"))
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

The reader rejects reserved command words as most user names. A dot separates
parts of a path: record fields, list positions, stage state locations, and
imported names. Simple procedure, input, value, result, loop, performer, resource, proposition,
import alias, and interface names do not contain dots.
A name used as a word has no spaces;
quoted workflow and stage titles can contain spaces. Procedure names must be
distinct; interface names must be distinct from each other and from procedures;
performer and resource names follow their declaration rules;
proposition names are unique within their type and parent;
stage names must be distinct across the assembled workflow. Each procedure has
distinct input names, and record fields are distinct within a record.
@secref["procedures"] explains local value scope and result names.

@section{Source files}

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
         "Declares record fields or workflow requirements")
   (list (tt "performer name [field = value ...]")
         "Top level of a workflow"
         "Declares an open performer object for paired stages")
   (list (tt "resource name [field = value ...]")
         "Top level of a workflow"
         "Names a data source or storage location")
   (list (tt "hypothesis name [text = \"...\"] (also assumption, conclusion)")
         "Top level of a workflow"
         "Declares a named proposition")))

A library import selects a tag or full commit ID on its @tt{main} branch.
@secref["libraries"] explains import, @tt{include}, repository layout, and
dependency rules. @secref["interfaces"] explains the two interface forms.
Workflow files may contain commands, procedures, stages, performers, resources,
propositions, interfaces,
obligations, and includes. A library file may contain imports, includes,
procedures, and record interfaces; it has no top-level executable commands.

@section{Where to find each form}

@(tabular #:style 'boxed
  (list
   (list (bold "Topic") (bold "Forms covered") (bold "Current behavior"))
   (list (secref "values")
         (tt "numbers, text, true, false, unknown, lists, records")
         "Values used by runnable forms")
   (list (secref "values")
         (tt "range, .field, .[ ... ], arithmetic, comparisons, not, and, xor, or")
         "Expressions used by runnable forms")
   (list (secref "uncertainty")
         (tt "value u [declared = [ ... ] omitted = [ ... ]], value.u")
         "Attached descriptions of named uncertainty sources")
   (list (secref "procedures")
         (tt "to, :input, do, as, output, name = value, name += value, print")
         "Definitions and executable commands")
   (list (secref "procedures")
         (tt "repeat, until, for each, while, if, else if, else")
         "Executable control flow")
   (list (secref "stages")
         (tt "stage \"title\"")
         "Section header for runnable commands")
   (list (secref "stages")
         (tt "performer, stage ... by ... from state, do ... by ... into, end stage with state, at")
         "Read and checked; paired body not executed")
   (list (secref "propositions")
         (tt "hypothesis, assumption, conclusion, +=, dotted paths")
         "Named declarations, nesting, and updates")
   (list (secref "resources")
         (tt "resource name [ ... ], name.field = value, value = name.field")
         "Data flow represented; no external I/O")
   (list (secref "interfaces")
         (tt "interface, version, extends, require, affects")
         "Declarations checked for structure")
   (list (secref "libraries")
         (tt "library, import, include")
         "Files and revisions resolved by reader")
   (list (secref "assessment")
         (tt "implements, provide, must do, must stages in order, must record implement")
         "Requirements on the written method")))

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
locations, resource paths, and the declared exit state. A state stage is read
and checked, but its body is not executed by the current interpreter.
Reading or writing data outside the workflow requires a declared
@tt{resource}; see @secref["resources"].
Proposition declarations use named collections. The reader catches repeated
top-level additions; the interpreter rejects other duplicates when a
runnable @tt{+=} command executes. See
@secref["propositions"].
Uncertainty descriptions accept only @tt{declared} and @tt{omitted}
collections of named sources; see @secref["uncertainty"].
Source-code paths in imports and includes have separate rules.
Structural obligations are assessed separately; a successful read does not
establish that scientific work occurred.
