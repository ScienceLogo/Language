#lang scribble/manual
@(require racket/runtime-path "site-head.rkt" "site-links.rkt")
@(define-runtime-path logo-path "../assets/logo.png")
@(define release-tag (getenv "SCIENCELOGO_RELEASE_TAG"))
@(define doc-commit (getenv "SCIENCELOGO_DOC_COMMIT"))

@title[#:style (page-style #:toc? #t)]{ScienceLogo}
@author{Riccardo Boero}

@image[logo-path #:scale 0.12]{ScienceLogo logo}

@bold{Humans first in AI science.}

@hyperlink["https://github.com/ScienceLogo/Language"]{Source code and issues}
@" · "
@hyperlink[(source-directory-url "spec")]{Language specifications}
@" · "
@hyperlink[(source-file-url "CITATION.cff")]{How to cite ScienceLogo}

@bold{Latest tagged release:} @(if release-tag
  (hyperlink (string-append "https://github.com/ScienceLogo/Language/tree/" release-tag)
             release-tag)
  "None yet")

@bold{Documentation source:} @(if doc-commit
  (hyperlink (string-append "https://github.com/ScienceLogo/Language/commit/" doc-commit)
             (substring doc-commit 0 (min 12 (string-length doc-commit))))
  "local checkout")

ScienceLogo is a Logo dialect for scientific workflows. It aims to make scientific
methods readable while giving people ways to inspect and supervise work performed
with AI. The language is under development: the current runnable subset is small,
and broader scientific and AI constructs are still being designed.

Start with @secref["getting-started"]. @secref["reference"] gives the language's
file structure, naming rules, and a map of every implemented form. The next
pages explain values, procedures, control flow, libraries, interfaces, and
assessment. The @hyperlink[(source-directory-url "spec")]{design specifications}
describe work beyond the runnable language.

@include-section["getting-started.scrbl"]
@include-section["reference.scrbl"]
@include-section["values.scrbl"]
@include-section["procedures.scrbl"]
@include-section["libraries.scrbl"]
@include-section["interfaces.scrbl"]
@include-section["assessment.scrbl"]
