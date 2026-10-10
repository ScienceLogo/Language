#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "reference"]{Syntax}

These forms are implemented in the current reader and assessor.

@itemlist[
  @item{@tt{workflow "title"} optionally names the whole workflow file for
        references and reports. It appears once as the first form, before imports or method forms,
        and does not enclose the file in brackets.}
  @item{@tt{to name :input ... [ ... ]} defines a procedure with optional inputs.
        It does not run until called. Definitions belong directly in a workflow file,
        library, or included file. Procedure names must be distinct.}
  @item{@tt{do name value ... as result} calls a procedure, optionally supplying
        values and naming its returned result.}
  @item{@tt{do [ ... ]} runs its commands once, in order.}
  @item{@tt{set name to value} creates or updates a named value. A new name
        belongs to the current block; a visible name created by @tt{set} can
        be updated from a nested block.}
  @item{@tt{repeat count [ ... ]} runs a block a fixed number of times.}
  @item{@tt{for each name in sequence [ ... ]} runs a block for each item in
        an ordered sequence. @tt{name} is local to each iteration.}
  @item{@tt{while condition [ ... ]} tests before each iteration.}
  @item{@tt{repeat [ ... ] until condition} runs at least once, then tests
        after each iteration. Its condition may refer to a value named in the block.}
  @item{@tt{if condition [ ... ] else if condition [ ... ] else [ ... ]}
        chooses the first true branch, or the optional @tt{else} branch.}
  @item{@tt{stage "name"} labels the following commands until the next stage header
        at the same nesting level or the end of the block. It is a section and
        checkpoint, not a command to run or a procedure to call. Stage names must be
        distinct across a workflow and its procedures.}
  @item{@tt{output value} returns a value from a procedure.}
  @item{@tt{print value} displays text. It does not record a scientific observation.}
  @item{@tt{library "name" [ ... ]} declares procedures in a library file.}
  @item{@tt{include "relative/path.rkt"} loads declarations from another file in
        the same library repository.}
  @item{@tt{import "Git URL" at "tag or commit" as alias} makes procedures in a
        library available through @tt{alias.procedure}. It appears at the top of
        a workflow file, before method forms, or directly inside a library block.}
  @item{@tt{interface "name" [version "..." require part ... affects source target ...]}
        declares required names and structural impact links in a separate file.}
  @item{@tt{must do name} declares that the investigation's written method must
        contain a reachable call to @tt{name}. It belongs directly in an investigation.}
  @item{@tt{must stages in order ["First" "Second" ...]} requires at least two
        distinct top-level stage headers in that order. Other stages may occur
        between them. It belongs directly in a workflow file.}
  @item{@tt{implements "relative/path.rkt" as alias [provide part by "reference" ...]}
        maps interface parts to text references inside an investigation.}
]

A value can be quoted text, a number, @tt{true}, @tt{false}, @tt{unknown}, a
list such as @tt{[1 2 3]}, a numeric range, a declared @tt{:input} inside its
procedure, or a name introduced earlier by @tt{as} or @tt{set}. For example:

@verbatim|{
set lengths to range 0.25 to 1.00 step 0.25
for each length in lengths [print length]
}|

The range includes its end only when an exact step lands on it. Bounds and
step may be numbers, procedure inputs, or named values. The step must be
nonzero and move toward the end; decimal inputs use exact arithmetic. Lists
can contain values and other lists. A @tt{for each} collection must evaluate
to an ordered list; separate loops can reuse one named list or range.

Conditions accept a boolean value or a comparison of two values with
@tt{=}, @tt{!=}, @tt{<}, @tt{<=}, @tt{>}, or @tt{>=}. Ordered comparisons
require numbers. @tt{unknown}, or any nonboolean condition, stops execution
with an explicit error; it never selects @tt{else} by default. The runner
stops a @tt{while} or @tt{repeat ... until} loop after 10,000 iterations
with a nontermination error.

A nested block can read values from its enclosing blocks and update a visible
@tt{set} name. New names introduced inside @tt{do}, a loop, or a branch stay
there; enclosing and sibling blocks cannot read them. Procedure inputs,
@tt{as} results, and @tt{for each} iteration names cannot be updated with
@tt{set}. The @tt{for each} name is available only in that loop body. A
procedure sees only its declared inputs, not the caller's result names.
Stage headers do not change this visibility: a result named before one stage
can be used in a later stage of the same block. A @tt{to} definition placed
between stage headers still belongs to its enclosing workflow.

Use @tt{;} for a line comment. A block comment begins with @tt{#|} and ends
with @tt{|#}; block comments can nest. Whitespace is flexible, and empty
blocks are allowed.

The reader validates a workflow file before running commands. It rejects
unknown or duplicate procedures, duplicate stage names, wrong input counts,
unknown input or result names, a requested result from a procedure without @tt{output}, malformed
brackets, unsupported commands, recursive calls, and a second or misplaced
workflow title. Library and interface files have their own declarations and
cannot contain a workflow title. Procedure definitions may appear after their calls.
Imported procedure and stage names carry their library alias, so separate libraries
can each define a procedure or stage with the same original name.

@section{Still being designed}

Scientific items, measurements, standards beyond the
current structural checks, other declarative obligations, agents, and evidence are
not implemented. The @hyperlink[(source-directory-url "spec")]{design specifications}
explore these concepts; their examples are not executable ScienceLogo programs.
