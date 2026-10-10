#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "reference"]{Syntax available today}

@itemlist[
  @item{@tt{investigate "question" [ ... ]} starts the one investigation in a file.}
  @item{@tt{to name :input ... [ ... ]} defines a procedure with optional inputs.
        It does not run until called. Definitions belong directly in an investigation,
        library, or included file.}
  @item{@tt{do name value ... as result} calls a procedure, optionally supplying
        values and naming its returned result.}
  @item{@tt{do [ ... ]} runs its commands once, in order.}
  @item{@tt{output value} returns a value from a procedure.}
  @item{@tt{print value} displays text. It does not record a scientific observation.}
  @item{@tt{library "name" [ ... ]} declares procedures in a library file.}
  @item{@tt{include "relative/path.rkt"} loads declarations from another file in
        the same library repository.}
  @item{@tt{import "Git URL" at "tag or commit" as alias} makes procedures in a
        library available through @tt{alias.procedure}. It appears before an
        investigation or directly inside a library block.}
  @item{@tt{interface "name" [version "..." require part ... affects source target ...]}
        declares required names and structural impact links in a separate file.}
  @item{@tt{implements "relative/path.rkt" as alias [provide part by "reference" ...]}
        maps interface parts to text references inside an investigation.}
]

A value can currently be quoted text, a declared @tt{:input} inside its
procedure, or a result named earlier with @tt{as}. A nested @tt{do [ ... ]}
block can read results from its enclosing blocks. Results named inside the
nested block stay there; enclosing and sibling blocks cannot read them. A
procedure sees only its declared inputs, not the caller's result names.

Use @tt{;} for a line comment. A block comment begins with @tt{#|} and ends
with @tt{|#}; block comments can nest. Whitespace is flexible, and empty
blocks are allowed.

The reader validates an investigation before running commands. It rejects
unknown or duplicate procedures, wrong input counts, unknown input or result
names, a requested result from a procedure without @tt{output}, malformed
brackets, unsupported commands, and recursive calls. Procedure definitions may
appear after their calls.

@section{Still being designed}

Scientific items, measurements, repetition, stages, standards beyond the
structural interface check, declarative obligations, agents, and evidence are
not implemented. The @hyperlink[(source-directory-url "spec")]{design specifications}
explore these concepts; their examples are not executable ScienceLogo programs.
