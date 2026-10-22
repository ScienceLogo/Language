# Releasing ScienceLogo

This guide describes package publication and archival. The
[specification guide](spec/README.md) defines the language; the
[manual](scribblings/sciencelogo.scrbl) documents its use and the reference
implementation's behavior.

## Prepare a release

1. Choose the release version and tag. Set the package version in `info.rkt`
   and the matching `version` and `date-released` in `CITATION.cff`.
2. Review the release notes against the specification and implementation.
   Describe the available tools and their limits without treating
   independent scientific applications as missing language features.
3. Build the manual, run the tests, and verify package archive creation and
   installation from a clean checkout of the release commit. CI provides
   the package and test checks; the documentation workflow builds the manual.
4. Confirm that the license, citation metadata, repository links, and
   examples are included in the source archive.

Build release archives from a clean checkout. `info.rkt` excludes local
workspace metadata from source packages.

## Publish and archive

1. Connect the public GitHub repository to Zenodo before the GitHub release
   to be archived. Enable the repository in Zenodo's GitHub integration.
2. Commit the reviewed release files and run CI on that commit. Create the
   version tag and GitHub release from the same commit. Zenodo ingests the
   release after the repository is enabled.
3. Check the resulting Zenodo record. Its **version DOI** identifies the
   exact archived release; its **concept DOI** identifies the series of
   releases. Add the concept DOI to the top-level `doi` field in
   `CITATION.cff`, as a bare `10.xxxx/...` value, once it exists. Keep a
   release-specific DOI in the corresponding release notes or citation
   when needed. A DOI minted after publication can be committed for
   subsequent releases.
4. Register the runnable, installable `sciencelogo` package in the Racket
   package catalog with the repository root as its source. The catalog
   points to the source rather than publishing a separate package binary.

Zenodo documents [enabling a repository](https://help.zenodo.org/docs/github/enable-repository/)
and [archiving a GitHub release](https://help.zenodo.org/docs/github/archive-software/github-upload/).
The [Citation File Format schema guide](https://github.com/citation-file-format/citation-file-format/blob/main/schema-guide.md)
describes the root `doi` field. The [Racket package guide](https://docs.racket-lang.org/pkg/getting-started.html)
explains catalog sources and package registration.

## Automation

The [CI workflow](.github/workflows/ci.yml) validates citation metadata,
creates and installs a Racket source package archive, and runs `raco test .`.
The [documentation workflow](.github/workflows/docs.yml) builds the manual
and deploys it to GitHub Pages from `main` and version tags.

Creating a GitHub release is a deliberate publication action. Zenodo handles
archival after the repository is connected. The repository workflows do not
create releases or register packages in the Racket catalog.
