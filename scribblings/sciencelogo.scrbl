#lang scribble/manual
@(require racket/runtime-path)
@(define-runtime-path logo-path "../assets/logo.png")

@title{ScienceLogo}
@author{Riccardo Boero}

@image[logo-path #:scale 0.12]{ScienceLogo logo}

@bold{Humans first in AI science.}

@hyperlink["https://github.com/ScienceLogo/Language"]{Source code and issues}
@" · "
@hyperlink["https://github.com/ScienceLogo/Language/tree/main/spec"]{Language specifications}
@" · "
@hyperlink["https://github.com/ScienceLogo/Language/blob/main/CITATION.cff"]{How to cite ScienceLogo}

ScienceLogo is a Logo dialect for scientific workflows. It aims to make scientific
methods readable while giving people ways to inspect and supervise work performed
with AI. The language is under development: the current runnable subset is a small
teaching slice, and the broader scientific and AI constructs are still being designed.

@section{Run your first investigation}

Install the package from a local checkout with @tt{raco pkg install --link .}, then
run @tt{racket examples/first-slice.rkt}. The example is:

@verbatim|{
#lang sciencelogo

investigate "How will we study plant growth?" [
  do [
    do introduce
    do finish
  ]

  to finish [
    print "Keep each observation with its date."
  ]

  to introduce [
    print "Measure plant height each day."
  ]
]
}|

It prints two lines in the order requested by the @tt{do} block. The procedure
definitions can appear after their calls.

@section{Pass a value and get a result}

A procedure can receive an item and give a result back:

@verbatim|{
#lang sciencelogo

investigate "What should we measure?" [
  do observation-plan "Bean plant" as plan
  print plan

  to observation-plan :plant [
    print :plant
    output "Measure its height each day."
  ]
]
}|

The call supplies @tt{"Bean plant"}. Inside the procedure, @tt{:plant} names that input.
@tt{output} gives a value back, and @tt{as plan} names it in the investigation. This
program prints @tt{Bean plant}, then @tt{Measure its height each day.} Run it from a
local checkout with @tt{racket examples/inputs-and-results.rkt}.

@section{Call a library}

A library is a separate Git repository with a @tt{main} branch and a
@tt{library.rkt} file at its root. For example, that file can contain:

@verbatim|{
#lang sciencelogo
library "hello-world" [
  include "greetings/hello.rkt"
]
}|

The included file @tt{greetings/hello.rkt} contains:

@verbatim|{
#lang sciencelogo
to say-hello [print "Hello, world!"]
}|

An investigation imports the library before its @tt{investigate} declaration:

@verbatim|{
#lang sciencelogo
import "https://example.org/hello-world.git" at "v1.0.0" as hello
investigate "Try a library" [
  do hello.say-hello
]
}|

Replace the example URL with a repository containing the library file. @tt{at}
selects a tag or full commit ID from @tt{main}; branch names are rejected.
@tt{hello} is the local alias, so @tt{do hello.say-hello} calls the imported
procedure. Importing alone does not run it. Git is required to resolve imports.
An included file may include further files. Paths are relative to the containing
file and must stay inside the repository. The reader rejects include cycles and
duplicate includes.

A library may import another library inside its @tt{library} block. For example,
a separate messages repository can provide @tt{to message :text [output :text]}.
The imported alias is available to the importing library's procedures, including
procedures in its included files:

@verbatim|{
#lang sciencelogo
library "welcome" [
  import "https://example.org/messages.git" at "v1.0.0" as messages
  to greet :person [
    do messages.message :person as greeting
    print greeting
  ]
]
}|

An investigation importing @tt{welcome} can call @tt{welcome.greet}. To call
@tt{messages.message} itself, the investigation also imports the messages
repository. The @tt{messages} alias inside @tt{welcome} does not become an alias
in the investigation. The reader records the resolved commits of dependencies
and rejects import cycles. Library imports belong directly in the root
@tt{library} block.

@section{Commands available today}

@itemlist[
  @item{@tt{import "Git URL" at "tag or commit" as alias} makes procedures in a
        library available through @tt{alias.procedure}. It appears before an
        investigation or directly inside a library block.}
  @item{@tt{investigate "question" [ ... ]} starts the one investigation in a file.}
  @item{@tt{library "name" [ ... ]} declares the procedures in a library file.}
  @item{@tt{include "relative/path.rkt"} loads declarations from a file in that
        library repository. It belongs directly in a library or included file.}
  @item{@tt{to name :input ... [ ... ]} defines a procedure with optional inputs.
        It does not run until called. Definitions belong directly in an investigation,
        library, or included file.}
  @item{@tt{do name value ... as result} calls a procedure, optionally supplying values
        and naming its returned result.}
  @item{@tt{do [ ... ]} runs its commands once, in order.}
  @item{@tt{output value} returns a value from a procedure.}
  @item{@tt{print value} displays a line of text. It does not record a scientific
        observation or evidence.}
]

For now, a value can be quoted text, a declared @tt{:input} inside its procedure,
or a result named earlier with @tt{as}. A nested @tt{do [ ... ]} block can read
results from its enclosing blocks. Results named inside the nested block stay there;
enclosing and sibling blocks cannot read them. A result name cannot duplicate an input
or another result visible in its block. Separate sibling blocks may use the same name.
A procedure sees only its declared inputs, not the caller's result names. The colon is
only used for procedure inputs.

Use @tt{;} for a line comment. A block comment begins with @tt{#|} and ends with
@tt{|#}; block comments can nest. Whitespace is flexible, and empty blocks are
allowed.

The reader checks the whole investigation before it runs. It rejects unknown or
duplicate procedure names, wrong input counts, unknown input or result names, calls
that request a result from a procedure without @tt{output}, malformed brackets,
unsupported commands, and recursive procedure calls. Procedure names are local to
the investigation.

@section{What is still being designed}

Scientific items, measurements, repetition, stages, standards, declarative obligations,
agents, and evidence are not implemented in this first slice. The
@hyperlink["https://github.com/ScienceLogo/Language"]{source repository}
contains further examples. Those examples explore
how human review, traceability, and control of AI work might become part of a
scientific method; they are not yet executable ScienceLogo programs.
