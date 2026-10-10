# Libraries

This page defines the ScienceLogo library layout and import form implemented by the
current `#lang sciencelogo` reader. Git must be available to resolve imports.

## A hello-world library

One Git repository provides one library. Its `main` branch contains `library.rkt` at
the repository root. A complete first library needs only that file:

```text
#lang sciencelogo

library "hello-world" [
  to greeting [output "Hello, world!"]
]
```

The `library` declaration gives the library its name. `greeting` returns a value;
loading the library does not print or run the procedure. Commit the file on `main`
and tag that commit `v1.0.0` before importing it.

An investigation imports a tagged release of that repository and calls the procedure
through its local alias:

```text
#lang sciencelogo

import "file:///absolute/path/to/hello-world" at "v1.0.0" as hello

investigate "Try a library" [
  do hello.greeting as message
  print message
]
```

Replace the example `file://` URL with the absolute path to your local Git
repository. An HTTPS Git URL works too. `at` selects a tag or a full commit ID
from `main`; branch names are not import targets. `as hello` names this import
within the investigation. `do hello.greeting` runs the procedure and gives its
returned value the local name `message`; the caller prints it. The dot separates
the alias from the procedure name; locally defined procedure names cannot contain
a dot.

The reader checks the library and records the resolved commit in the loaded program
before any investigation command runs. A library does not need a central ScienceLogo
repository or catalog.

A larger library may move the procedure to another file. Its root entry then has
`include "greetings/greeting.rkt"`, and that included file has the top-level
`to greeting [output "Hello, world!"]` definition with its own
`#lang sciencelogo` line. Included files may include further files. Paths are
relative to the containing file and must stay inside the repository. The reader
rejects include cycles and duplicate includes.

## A library can use another library

A library can put an `import` directly in its `library` block. For a complete
example, the root `library.rkt` in a messages repository contains:

```text
#lang sciencelogo

library "messages" [
  to greeting [output "Hello, world!"]
]
```

The root `library.rkt` in a second repository can then use that procedure:

```text
#lang sciencelogo

library "welcome" [
  import "file:///absolute/path/to/messages" at "v1.0.0" as messages

  to opening [
    do messages.greeting as text
    output text
  ]
]
```

The alias `messages` belongs to the `welcome` library. It is available to the
library's procedures, including procedures in included files. An investigation
that imports `welcome` can call `welcome.opening`, but it cannot call
`welcome.messages.greeting` or `messages.greeting` through that import. To use
`greeting` directly, the investigation imports the messages repository too, with
its own alias:

```text
#lang sciencelogo

import "file:///absolute/path/to/welcome" at "v1.0.0" as welcome
import "file:///absolute/path/to/messages" at "v1.0.0" as messages

investigate "Use both libraries" [
  do welcome.opening as opening
  print opening
  do messages.greeting as direct
  print direct
]
```

Replace both example URLs with the absolute paths to the respective repositories.
Each library import selects a tag or full commit ID on that library's `main`
branch. The reader resolves dependencies before running the investigation,
records their exact commits, and rejects import cycles. Imports belong directly
in the root `library` block; included files contain `to` and `include`
declarations.
