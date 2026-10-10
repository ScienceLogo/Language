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

Start with @secref["getting-started"], then read @secref["libraries"] for reusable
procedures or @secref["interfaces"] for structural assessment. @secref["reference"]
lists the syntax that runs today.

@include-section["getting-started.scrbl"]
@include-section["libraries.scrbl"]
@include-section["interfaces.scrbl"]
@include-section["reference.scrbl"]
