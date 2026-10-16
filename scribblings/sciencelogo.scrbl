#lang scribble/manual
@(require racket/runtime-path "site-head.rkt" "site-links.rkt")
@(define-runtime-path logo-path "../assets/logo.png")
@(define release-tag (getenv "SCIENCELOGO_RELEASE_TAG"))
@(define doc-commit (getenv "SCIENCELOGO_DOC_COMMIT"))

@title[#:style (page-style #:toc? #t)]{ScienceLogo}
@author{Riccardo Boero}

@para[#:style "docs-logo-asset"]{@image[logo-path #:scale 0.12]{ScienceLogo logo}}

@bold{Humans first in AI science.}

@bold{Human-centered scientific workflows in the AI era.}

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

ScienceLogo is a Logo dialect for describing scientific workflows that people
can read and inspect. It aims to keep the purpose, structure, assumptions,
and conditions of a method understandable to people, including when AI
participates. The language is under development: the current runnable subset
is small, and broader scientific and AI constructs are still being designed.

@section{Current language status}

@(tabular #:style 'boxed
  (list
   (list (bold "Part") (bold "Current behavior"))
   (list (secref "values")
         "Values, records, expressions, and ranges run")
   (list (secref "procedures")
         "Procedures, assignments, branches, and loops run")
   (list (secref "libraries")
         "Includes and pinned Git library imports are resolved")
   (list (secref "stages")
         "Simple headers label commands; paired stages are read and checked as a written method")
   (list (secref "resources")
         "Data reads and writes are represented; no external data is transferred")
   (list (secref "assessment")
         "The assessor checks declared method structure and record fields")))

Scientific adequacy, protocol conformance, bias and uncertainty analysis,
records of observed runs, and the planned verbose syntax remain outside the
current implementation. The
@hyperlink[(source-file-url "spec/README.md")]{specification index} identifies
which design documents describe future work.

Start with @secref["getting-started"], then use @secref["reference"] to find
a form or naming rule. The remaining pages move from values and procedures to
stages, data sources and storage, reusable definitions, and declared checks. Each
page states what its forms currently do.

@include-section["getting-started.scrbl"]
@include-section["reference.scrbl"]
@include-section["values.scrbl"]
@include-section["procedures.scrbl"]
@include-section["stages.scrbl"]
@include-section["resources.scrbl"]
@include-section["interfaces.scrbl"]
@include-section["libraries.scrbl"]
@include-section["assessment.scrbl"]
