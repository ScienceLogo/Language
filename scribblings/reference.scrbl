#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "reference"]{Syntax}

This page is the syntax map for @tt{#lang sciencelogo}. Read
@secref["getting-started"] to learn the basic pattern; follow the links below
for each form's full rule. Most forms run. Paired stages and their location
calls are read and checked as a written method but are not executed. The
@hyperlink[(source-file-url "spec/README.md")]{specification guide} links
the language contracts separately from rationale and earlier design notes.
Within an interface, @tt{must [...]} groups required entries and their
defaults. @tt{name [...]} gives a part its own nested entries. Bare entries
without defaults are optional. An @tt{is} constraint outside @tt{must},
such as @tt{notes is text}, checks the field when supplied; see
@secref["interfaces"].

@secref["compact-grammar"] collects all compact forms and their parsing rules
in one reference, with a standalone grammar for implementations in other
languages.

@secref["verbose-syntax"] gives the accepted word-based equivalents and
examples of mixed source. All spellings normalize to compact syntax before
the same parsing and language checks.

@section{How to read the forms}

In a form such as @tt{to name :input [ ... ]}, command words such as @tt{to}
are written literally; @tt{name}, @tt{input}, and @tt{...} stand for content
you supply. Square brackets shown in a form are literal ScienceLogo
brackets. Quoted text is a text value. Commands may share a line or use
separate lines.

At command position, @tt{name = value} assigns a value. Equality comparisons
use @tt{==}. Within a record or dotted update, @tt{=} supplies a field
value; within an interface, it supplies a default. At command position,
@tt{name += [field = value]} updates or adds record fields, while
@tt{name.field += number} adds to an existing numeric field. On a list,
@tt{name += value} appends one item. See
@secref["procedures"] for scope.

@section{Names and labels}

Names are case-sensitive. The table gives the project's spelling convention.
These conventions are optional guidance for readable workflows. Capitalization
and hyphens do not determine what a name represents and are not validation
requirements. The declaration identifies an interface. For example,
@tt{Timing}, @tt{timing}, and @tt{timing_shape} can each name an interface;
they remain distinct names because names are case-sensitive.

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
   (list "Stage" "Lowercase words joined by hyphens"
         (tt "measure-the-pendulum"))
   (list "Workflow title" "Readable quoted text"
         (tt "\"Measure the pendulum\""))
   (list "Source file or directory" "Lowercase words joined by hyphens"
         (tt "methods/estimate-period.rkt"))))

Names are unquoted identifiers in declarations and references. Quotes mark
string values, including descriptions, file paths, URLs, versions, and the
workflow's human-readable title. An interface is declared as
@tt{interface Timed-observation [ ... ]}, and referred to as
@tt{Timed-observation}. An imported interface is @tt{alias.Timed-observation};
an imported procedure is @tt{alias.estimate-period}. A library also declares
an unquoted name, as in @tt{library pendulum-tools [ ... ]}; imports use its
Git URL and the chosen alias. A stage is declared as @tt{stage measure} and
referenced as @tt{measure}, including in implementation mappings and
@tt{must stages in order [prepare measure]}.

The reader rejects reserved command words as most user names. A dot separates
parts of a path: record fields, list positions, stage state locations, and
imported names. Simple procedure, input, value, result, loop, performer, resource, proposition,
import alias, stage, library, and interface names do not contain dots.
A name used as a word has no spaces. Stage, library, and interface names
cannot start with a number. Hyphenation and capitalization remain optional
conventions. A workflow title is a string and can contain spaces. Procedure names must be
distinct; interface names must be distinct from each other and from procedures;
performer and resource names follow their declaration rules;
proposition names are unique within their type and parent;
stage names must be distinct across the assembled workflow. Each procedure has
distinct input names, and record fields are distinct within a record.
@secref["procedures"] explains local value scope and result names.

A stage reference in an @tt{implement} mapping is resolved from its declaration,
including a later declaration or an imported qualified name such as
@tt{timing.measure}. Quotes and capitalization do not select the target's kind.
If that reference could also identify a visible value or another definition,
the reader reports an ambiguous implementation target. A stage name does not
become a data value or a callable function.

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
   (list (tt "about \"Markdown text\"") "After the optional workflow title, before imports"
         "Describes the workflow; also attaches to stages and procedures")
   (list (tt "library name [ ... ]") (tt "library.rkt") "Declares reusable procedures and record interfaces")
   (list (tt "import \"Git URL\" at \"tag\" as alias")
         "After an optional workflow title and description, before method forms; or directly in a library"
         "Loads a pinned library")
   (list (tt "include \"relative/path.rkt\"")
         "Top level of a workflow or library file"
         "Loads another file from the same repository")
   (list (tt "interface name [ ... ]")
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

@section[#:tag "descriptions"]{Describe a workflow, stage, or procedure}

@tt{about "text"} supplies an optional description in CommonMark Markdown.
It uses ordinary quoted text, which may span lines; escaped quotes and
backslashes follow the usual string rules. No headings or template are
required. A short opening summary is recommended. Explain purpose,
assumptions, limits, or how to interpret results when that helps a reader.

@(tabular #:style 'boxed
  (list
   (list (bold "What it describes") (bold "Where to place about"))
   (list "Workflow" "After its optional title, before imports and other forms")
   (list "Procedure" "First inside the opening bracket of its to definition")
   (list "Simple stage" "Immediately after its stage header")
   (list "Paired stage" "Immediately after its complete opening header and entry state")))

@code-example|{
#lang sciencelogo
workflow "Review a timing plan"
about "Explain how to time a pendulum as the swing gets smaller."

stage Prepare
about "Prepare the timing plan."
do make-plan as plan

to make-plan [
  about "Return a timing plan, with its **purpose**."
  output "Time ten swings as the swing gets smaller."
]

stage Review
about "Read the plan."
print plan
}|

Each workflow, stage, or procedure may have one description. Whitespace and
comments may separate it from its header; commands may not. A workflow
without a title may begin with @tt{about}. Procedures in libraries and
included files follow the same rule. A description on a nested stage
belongs to that stage, separately from its procedure's description.

A workflow description can summarize the question, scope, and limits. A
stage description can explain its checkpoint or work. A procedure
description can explain a reusable method and its limitations; its inputs
and results remain defined by the code. An empty description is allowed.

The reader preserves the text and its source location for inspection and
external documentation tools. It does not render Markdown or treat prose
as a declaration or a condition. Descriptions have no effect on execution
or check results. Anonymous @tt{do}, @tt{if}, and loop blocks, libraries,
and interfaces have no @tt{about} attachment; use comments for local notes.
The @hyperlink[(source-file-url "spec/descriptions.md")]{description contract}
records these rules and the workflow model accessors.

@section{Where to find each form}

@(tabular #:style 'boxed
  (list
   (list (bold "Topic") (bold "Forms covered") (bold "Purpose and behavior"))
   (list (secref "descriptions")
         (tt "about \"Markdown text\"")
         "Optional explanation attached to a workflow, stage, or procedure")
   (list (secref "values")
         (tt "numbers, text, true, false, unknown, lists, records")
         "Values used by runnable forms")
   (list (secref "values")
         (tt "range, .field, .[ ... ], .count, arithmetic, comparisons, in, is, not, and, xor, or")
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
         (tt "stage name")
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
         (tt "interface, version, extends, must [...], if, else if, else, for each, affects")
         "Declarations checked for structure")
   (list (secref "libraries")
         (tt "library, import, include")
         "Files and revisions resolved by reader")
   (list (secref "assessment")
         (tt "subject implement Interface.part, must do, must stages in order")
         "Interface mappings and requirements on the written method")))

@section{Comments and whitespace}

@tt{;} begins a line comment. @tt{#|} and @tt{|#} enclose a block comment;
block comments can nest. Whitespace is flexible, and empty blocks are allowed.
Parentheses group value expressions; brackets delimit blocks, lists, and
named-field records. The reader and workflow model preserve every explicit
parenthesis group, including nested and redundant groups. Evaluation and
checks respect the written grouping.

@section{What the reader checks}

Before running a workflow, the reader rejects malformed brackets, unsupported
commands, duplicate names, unknown procedures or values, wrong input counts,
a requested result from a procedure without @tt{output}, recursive procedure
calls, invalid interface inheritance, and misplaced file-level forms.
For state stages it also checks named input locations, compulsory return
locations, resource paths, and the declared exit state. A state stage is read
and checked, but its body is not executed by the reference interpreter.
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
