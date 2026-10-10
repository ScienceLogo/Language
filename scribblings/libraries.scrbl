#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "libraries"]{Libraries}

A ScienceLogo library is one Git repository with a @tt{main} branch and a
@tt{library.rkt} file at its root. An investigation imports a tagged version of
that repository. Importing makes its procedures available; a @tt{do} call uses one.

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

import "file:///absolute/path/to/hello-world" at "v1.0.0" as hello

investigate "Try a library" [
  do hello.greeting as message
  print message
]
}|

The @tt{at} value selects a tag or full commit ID reachable from @tt{main}; it
does not select a branch. @tt{hello} is the local alias for this import. The call
returns @tt{"Hello, world!"} as @tt{message}, and the investigation displays it.
The reader resolves and validates the library before running the investigation.

For larger libraries, the root @tt{library.rkt} can contain
@tt{include "relative/path.rkt"} declarations and imports of other libraries.
Included files contain top-level @tt{to} and @tt{include} declarations. A
dependency alias stays inside the library that declared it; an investigation
imports that dependency separately if it needs to call it directly. The
@hyperlink[(source-file-url "spec/libraries.md")]{library specification}
has the full layout and dependency rules.
