# Releasing ScienceLogo

This guide describes package publication and archival. The
[specification guide](spec/README.md) defines the language; the
[manual](scribblings/sciencelogo.scrbl) documents its use and the reference
implementation's behavior.

## Prepare a release

1. Choose the release version and tag, for example `0.1` and `v0.1`.
   Set the package version in `info.rkt` and the matching `version` in
   `CITATION.cff`. Use Racket's canonical version form: `0.1`, not `0.1.0`.
   Set `date-released` in `CITATION.cff` when the publication date is known.
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
2. Commit and push the reviewed release files and wait for CI and the manual
   build to pass. Create and push the version tag from that same commit:

   ```sh
   git tag v0.1
   git push origin v0.1
   ```

   The **Prepare release** workflow builds and installs the source package,
   checks the versions, and runs the tests. It then creates a **draft**
   GitHub release with `sciencelogo.zip` and `sciencelogo.zip.CHECKSUM`
   attached. Review its release notes and publish the draft in GitHub.
   Zenodo ingests the published release after the repository is enabled.
   If you publish the release before packaging finishes, the workflow can
   also attach the missing files to that published release, provided GitHub
   still allows attachments.
3. Check the resulting Zenodo record. Its **version DOI** identifies the
   exact archived release; its **concept DOI** identifies the series of
   releases. Add the concept DOI to the top-level `doi` field in
   `CITATION.cff`, as a bare `10.xxxx/...` value, once it exists. Keep a
   release-specific DOI in the corresponding release notes or citation
   when needed. A DOI minted after publication can be committed for
   subsequent releases.
   The manual's About and citation page reads `CITATION.cff` during the
   documentation build. Committing the DOI updates the displayed citation
   and archive link through the documentation workflow.
4. After the first release is published and both attachments are available,
   register `sciencelogo` once in the Racket package catalog with this source:

   ```text
   https://github.com/ScienceLogo/Language/releases/latest/download/sciencelogo.zip
   ```

   Mark the published release as the latest release in GitHub. Future
   releases use the same attachment names, so this address follows the latest
   published release. The catalog periodically detects checksum changes;
   users install updates with `raco pkg update sciencelogo`. Racket retrieves
   the package from GitHub, independently of Zenodo archival.

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

The [release workflow](.github/workflows/release.yml) runs when a `v*` tag is
pushed. It checks that the tag, `info.rkt`, and `CITATION.cff` agree, tests the
package, and attaches the archive and Racket-generated checksum to a draft
release. It can also be run from **Actions → Prepare release → Run workflow**
with an existing tag. Reruns replace attachments only while the release is
still a draft. For a published release, the workflow verifies any existing
archive and checksum and uploads only missing files. Existing published
attachments are never replaced. An immutable release must already contain
both files.

When recovering from a workflow error fixed after a tag was created, run the
workflow from `main` with that existing tag as the input. **Re-run jobs** on
the old run uses its original workflow and will repeat the old error.

Publishing the prepared draft remains a deliberate action in GitHub. Zenodo
handles archival after the repository is connected. The workflows do not
register packages in the Racket catalog.
