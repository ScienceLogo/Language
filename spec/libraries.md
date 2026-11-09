# Libraries

This page defines the ScienceLogo library layout and import rules. The
`#lang sciencelogo` reader uses Git to resolve imports.

## A hello-world library

One Git repository provides one library. Its `main` branch contains `library.rkt` at
the repository root. A complete first library needs only that file:

```text
#lang sciencelogo
; @doc url: https://example.org/hello-world/

library hello-world language "0.2" [
  to greeting [output "Hello, world!"]
]
```

The comment line is optional; see
[documentation links for tools](#documentation-links-for-tools).
`language "0.2"` is optional too; see [language version](#language-version).

The `library` declaration gives the library its unquoted identifier. Library,
interface, and procedure names are unquoted in declarations and references;
quoted strings supply values such as output text, paths, URLs, and versions.
`greeting` returns a value;
loading the library does not print or run the procedure. Commit the file on `main`
and tag that commit `v1.0.0` before importing it.

An investigation imports a tagged release of that repository and calls the procedure
through its local alias:

```text
#lang sciencelogo

workflow "Try a library"
import "file:///absolute/path/to/hello-world" at "v1.0.0" as hello
do hello.greeting as message
print message
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

## Language version

A library can state the ScienceLogo language version it was written and
checked with, after its name: `library hello-world language "0.2" [ ... ]`.
The version is a two-part number, such as `"0.2"`. The statement is
optional, and it is not a limit: the reader loads the library under any
language version. If the library fails to load under another version, the
error also names the stated version and the version the reader implements.
The import record in the workflow model keeps the stated version.

The library's own tags, such as `v1.0.0`, are separate from the language
version.

## Documentation links for tools

A library can tell documentation tools where its own documentation is
published. Put a `@doc url:` marker in a comment at the top of `library.rkt`,
after `#lang sciencelogo` and before the `library` form:

```text
; @doc url: https://example.org/hello-world/
```

A marker has the form `@doc key: value`, in a `;` or `#| ... |#` comment.
Only `url` is used so far, and its value is an `http` or `https` address. The
[ScienceLogo Documenter](https://github.com/ScienceLogo/Documenter)
reads it and links a workflow's documentation to the library's pages instead
of generating them again. If a key appears more than once, the first marker is
used and the Documenter warns.

The marker is a tool convention, not ScienceLogo syntax. The reader ignores
comments, so the marker does not change the library, its checks, or the
workflow model. A library without it remains valid.

## Interfaces in libraries

A library may also export a record interface. For example, `library.rkt` can
contain:

```text
#lang sciencelogo

library timing [
  interface Timing [must [duration unit = "seconds"]]
]
```

After committing and tagging that repository, an investigation can use it:

```text
import "file:///absolute/path/to/timing" at "v1.0.0" as timing
interface Timed-place [extends timing.Timing must [place]]
trial = Timed-place.[duration = 2 place = "lab"]
trial implement timing.Timing
```

An imported interface is named `alias.Interface` in construction, `extends`,
`is` tests, and `... implement`. For example, `must [timing is timing-tools.Timing]`
reuses an imported interface for a nested field. The importing
workflow can define its own interface that extends an imported one.
Capitalization and hyphenated names are optional conventions. An interface
declared as `timing_shape` is referenced as `alias.timing_shape`; declarations
determine its identity in constructors, tests, defaults, and nested mappings.
Names remain case-sensitive. Dependency aliases keep their existing privacy
regardless of capitalization.

A larger library may move the procedure or interface to another file. Its root entry then has
`include "greetings/greeting.rkt"`, and that included file has the top-level
`to greeting [output "Hello, world!"]` definition with its own
`#lang sciencelogo` line. An included file may instead declare a record
interface. Included files may include further files. Paths are
relative to the containing file and must stay inside the repository. The reader
rejects include cycles and duplicate includes.

## A library can use another library

A library can put an `import` directly in its `library` block. For a complete
example, the root `library.rkt` in a messages repository contains:

```text
#lang sciencelogo

library messages [
  to greeting [output "Hello, world!"]
]
```

The root `library.rkt` in a second repository can then use that procedure:

```text
#lang sciencelogo

library welcome [
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

workflow "Use both libraries"
import "file:///absolute/path/to/welcome" at "v1.0.0" as welcome
import "file:///absolute/path/to/messages" at "v1.0.0" as messages
do welcome.opening as opening
print opening
do messages.greeting as direct
print direct
```

Replace both example URLs with the absolute paths to the respective repositories.
The same visibility rule applies to an interface in a dependency: import that
dependency directly to use `alias.Interface` in the workflow. Each library
import selects a tag or full commit ID on that library's `main`
branch. The reader resolves dependencies before running the investigation,
records their exact commits, and rejects import cycles. Imports belong directly
in the root `library` block; included files contain `to`, record `interface`, and `include`
declarations.
