# Changelog

Each ScienceLogo release is a language version with a two-part number, such
as `0.2` or `0.3`. A language version is a fixed set of definitions: its
syntax and the workflow model the reader produces. Every change, including
a fix to the implementation or the documentation, is released as a new
language version; there are no patch releases. Packages built on ScienceLogo
can add a patch number to every release, but their first two numbers name
the language version they support: version `0.2.3` of such a package
works with language version `0.2`. Each release tag is `v` followed by the version, such as `v0.2`.
The Racket package catalog offers only the latest release; earlier releases
remain available from their GitHub tags and releases.

## 0.2 — 2026-11-09

### Added

- `phase` groups stages under a name, with an optional `about`. The workflow model records phases and where each stage, phase, and procedure ends.
- A library can state the language version it was written for: `library name language "0.2" [ ... ]`.

### Changed

- A procedure's `about` now goes before its opening bracket: `to name :input about "..." [ ... ]`.

### Fixed

- Local `include` no longer requires Git.

## 0.1 — 2026-10-23

Initial release of the language specification, compact and verbose syntax, Racket implementation, structural checks, translation, documentation and examples.
