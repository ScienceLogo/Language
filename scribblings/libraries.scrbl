#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "libraries"]{Files and libraries}

Use @tt{include} to split one workflow across local files. Use @tt{import} to
reuse a versioned library from another Git repository. A ScienceLogo library
is one Git repository with a @tt{main} branch and a @tt{library.rkt} file at
its root. Importing makes its procedures and record interfaces available.

@section{Split one workflow across files}

Every included file begins with @tt{#lang sciencelogo}. Its path starts at the
directory of the file containing @tt{include}; it must stay in the same Git
repository. An included workflow file has no workflow title or import and can
include more files. For example, these three paths are in one repository:

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

The reader assembles and validates the workflow before running it. Missing
files, duplicate includes, and cycles are errors. @tt{include} does not
create a local scope.

@section{Library syntax}

@(tabular #:style 'boxed
  (list
   (list (bold "Form") (bold "Rule"))
   (list (tt "library \"name\" [ ... ]")
         "One declaration in the root library.rkt file; contains imports, includes, procedures, and record interfaces")
   (list (tt "import \"Git URL\" at \"tag or commit\" as alias")
         "Directly in a library block, or at the top of an entry workflow")
   (list (tt "include \"relative/path.rkt\"")
         "Loads a file relative to the file containing this include")
   (list (tt "do alias.procedure ...")
         "Calls an imported procedure")
   (list (tt "alias.Interface")
         "Names an imported record interface in a value or declaration")))

The URL begins with @tt{https://} or @tt{file://}. @tt{at} selects a tag or
full commit ID reachable from the library's @tt{main} branch, not a branch
name. An alias is local to the file that declares the import. A library may
import another library; a workflow imports that dependency itself if it needs
to use the dependency's procedures or interfaces directly. Importing a
library never runs its procedures.

@section{Make a small library}

Create a separate directory named @tt{hello-world}. Save this as its
@tt{library.rkt}:

@verbatim|{
#lang sciencelogo

library "hello-world" [
  to greeting [output "Hello, world!"]
]
}|

The @tt{greeting} procedure returns text. Loading the library does not print it.
In that directory, initialize and tag the Git repository:

@verbatim|{
git init --initial-branch=main
git add library.rkt
git -c user.name="ScienceLogo example" -c user.email="example@example.invalid" commit -m "Add greeting library"
git tag v1.0.0
}|

@section{Import and call it}

Save the following investigation in another file. Replace the example
@tt{file://} URL with the absolute path to your @tt{hello-world} directory:

@verbatim|{
#lang sciencelogo

workflow "Try a library"
import "file:///absolute/path/to/hello-world" at "v1.0.0" as hello
do hello.greeting as message
print message
}|

The @tt{at} value selects a tag or full commit ID reachable from @tt{main}; it
does not select a branch. @tt{hello} is the local alias for this import. The call
returns @tt{"Hello, world!"} as @tt{message}, and the investigation displays it.
The reader resolves and validates the library before running the investigation.

@section{Share a record interface}

A library can also define a record interface, for example in @tt{library.rkt}:

@verbatim|{
#lang sciencelogo

library "timing" [
  interface "Timing" [duration unit = "seconds"]
]
}|

After committing and tagging that repository, a workflow can import and use it:

@verbatim|{
import "file:///absolute/path/to/timing" at "v1.0.0" as timing
interface "Timed-place" [extends timing.Timing place]
set trial to Timed-place but [duration = 2 place = "lab"]
must trial implement timing.Timing
}|

The alias qualifies the interface name just as it qualifies a procedure name.
Interfaces may also be placed in included library files. An included file can
use @tt{include "../shared/file.rkt"} from a subdirectory: the path starts at
the directory containing that include, and must stay in the same repository.

For larger libraries, the root @tt{library.rkt} can contain
@tt{include "relative/path.rkt"} declarations and imports of other libraries.
Included files contain top-level @tt{to}, record @tt{interface}, and
@tt{include} declarations. A dependency alias stays inside the library that
declared it; a workflow imports that dependency separately if it needs to use
its procedures or interfaces directly. The
@hyperlink[(source-file-url "spec/libraries.md")]{library specification}
has the full layout and dependency rules.
