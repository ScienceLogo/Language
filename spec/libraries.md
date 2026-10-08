# Libraries

This page defines the ScienceLogo library layout and import form implemented by the
current `#lang sciencelogo` reader. Git must be available to resolve imports.

## A hello-world library

One Git repository provides one library. Its `main` branch contains `library.rkt` at
the repository root. For a library called `hello-world`, that file contains:

```text
#lang sciencelogo

library "hello-world" [
  include "greetings/hello.rkt"
]
```

The included file `greetings/hello.rkt` contains the procedure:

```text
#lang sciencelogo

to say-hello [
  print "Hello, world!"
]
```

The `library` declaration gives the library its name. The entry file may define
procedures directly or include files containing top-level `to` definitions. Included
files may include further files. Paths are relative to the file containing the
`include` and must stay inside the library repository. The reader rejects cycles and
duplicate includes. All these procedures are available to importers. Loading the
library does not run an investigation.

An investigation imports a tagged release of that repository and calls the procedure
through its local alias:

```text
#lang sciencelogo

import "https://example.org/hello-world.git" at "v1.0.0" as hello

investigate "Try a library" [
  do hello.say-hello
]
```

The URL is an example address, not a published library; replace it with the URL of a
repository containing the `library.rkt` shown above. `at` selects a tag or a full commit
ID from `main`; branch names are not import targets. `as hello` names this import
within the investigation. Importing makes the library's procedures available, but
only `do hello.say-hello` runs the procedure. With that library, the investigation
prints `Hello, world!`. The dot in `hello.say-hello` separates the alias from the
procedure name; locally defined procedure names cannot contain a dot.

The reader checks the library and records the resolved commit in the loaded program
before any investigation command runs. A library does not need a central ScienceLogo
repository or catalog.

## A library can use another library

A library can put an `import` directly in its `library` block. For a complete
example, the root `library.rkt` in a messages repository contains:

```text
#lang sciencelogo

library "messages" [
  to message :text [output :text]
]
```

The root `library.rkt` in a second repository can then use that procedure:

```text
#lang sciencelogo

library "welcome" [
  import "https://example.org/messages.git" at "v1.0.0" as messages

  to greet :person [
    do messages.message :person as greeting
    print greeting
  ]
]
```

The alias `messages` belongs to the `welcome` library. It is available to the
library's procedures, including procedures in included files. An investigation
that imports `welcome` can call `welcome.greet`, but it cannot call
`welcome.messages.message` or `messages.message` through that import. To use
`message` directly, the investigation imports the messages repository too, with
its own alias:

```text
#lang sciencelogo

import "https://example.org/welcome.git" at "v1.0.0" as welcome
import "https://example.org/messages.git" at "v1.0.0" as messages

investigate "Use both libraries" [
  do welcome.greet "Galileo"
  do messages.message "ScienceLogo" as note
  print note
]
```

Each library import selects a tag or full commit ID on that library's `main`
branch. The reader resolves dependencies before running the investigation,
records their exact commits, and rejects import cycles. Imports belong directly
in the root `library` block; included files contain `to` and `include`
declarations.
