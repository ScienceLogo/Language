# Release plan

**Status:** preparing the first public draft. A small `#lang sciencelogo` control-flow
slice runs, but no release has been tagged and the repository has not been registered
in the Racket package catalog.

## Release target

The working target is a small, runnable first draft of `#lang sciencelogo`. Its documented
features should match its implementation. The [plant growth example](examples/plant-growth.md)
is the first readability test; the [knowledge synthesis](examples/knowledge-synthesis.md) and
[rainfall modelling](examples/rainfall-modelling.md) examples exercise AI participation,
obligations, evidence, and human review. These examples are currently design sketches.

Before a Racket package release, implement a minimal language reader and a representative
executable program, document its supported constructs, add a test that runs the program, and
check installation from a clean checkout. Set a package version in `info.rkt` and a matching
`version` and `date-released` in `CITATION.cff` when the release is ready. If we choose to
publish the design earlier, label it clearly as a design preview and defer catalog registration.

The first reader resolves `do` calls against `to` definitions in the whole containing
scope, including definitions written after a call. It currently supports `print` as a
visible teaching action, not scientific measurement or evidence. A proposed unordered
activity group should enter the release scope only after its completion and failure
rules are settled.

## Current preparation

- [x] State the purpose, draft status, and reading path in the README and examples.
- [x] Add the MIT license and matching Racket package metadata.
- [x] Add `CITATION.cff` with author, ORCID, repository, and license metadata.
- [x] Add CI checks for citation metadata, package archive creation, and tests.
- [x] Implement and test the first runnable language slice.
- [x] Document the supported syntax and current limitations in `spec/first-slice.md`.
- [ ] Build and install the package from a clean checkout.
- [ ] Review release notes and choose a version and tag.

An isolated package archive assembled from the current working files has been built,
installed, and tested. The clean-checkout gate remains for the release commit.

Build release archives from a clean checkout. CI creates a source package, and
`info.rkt` excludes local workspace metadata as an extra safeguard.

## Publish and archive

1. Make the GitHub repository public and connect it to Zenodo **before** the first GitHub
   release. Enable the repository in Zenodo's GitHub integration.
2. Commit the reviewed release files. Run CI on the release commit. Create a version tag
   and GitHub release from that commit. Zenodo will ingest the release after the repository
   is enabled.
3. Check the resulting Zenodo record and distinguish its **version DOI** (the exact archived
   release) from its **concept DOI** (the series of releases). Add the concept DOI to the
   top-level `doi` field in `CITATION.cff`, as a bare `10.xxxx/...` value, once it exists.
   Keep the release-specific DOI in the corresponding release notes or citation if needed.
   The first archived release cannot itself contain a DOI minted only after its publication;
   commit the concept DOI for subsequent releases.
4. Once the package is runnable and installable, register `sciencelogo` in the Racket package
   catalog with the repository root as its source. The catalog points to the source; it does
   not publish a separate package binary.

Zenodo [documents enabling a repository](https://help.zenodo.org/docs/github/enable-repository/)
and [archiving a GitHub release](https://help.zenodo.org/docs/github/archive-software/github-upload/).
The [Citation File Format schema guide](https://github.com/citation-file-format/citation-file-format/blob/main/schema-guide.md)
allows the concept DOI in the root `doi` field. The [Racket package guide](https://docs.racket-lang.org/pkg/getting-started.html)
explains catalog sources and package registration.

## Automation

The [CI workflow](.github/workflows/ci.yml) checks pushes, pull requests, and version tags.
It validates citation metadata, creates and installs a Racket package archive, and runs
`raco test`. The language tests cover forward calls, ordered blocks, comments, unknown
and duplicate names, malformed blocks, and recursion rejection. Publication stays a
deliberate GitHub release action; Zenodo handles archival after the repository is
connected. No automatic catalog registration or GitHub release creation is configured.
