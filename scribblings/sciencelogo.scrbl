#lang scribble/manual
@(require racket/runtime-path "site-head.rkt" "site-links.rkt" "citation-data.rkt")
@(define-runtime-path logo-path "../assets/logo.png")
@(define release-tag (getenv "SCIENCELOGO_RELEASE_TAG"))

@title[#:style (page-style #:toc? #t)]{ScienceLogo}
@(apply author (map citation-author-name (hash-ref project-citation "authors")))

@para[#:style "docs-logo-asset"]{@image[logo-path #:scale 0.12]{ScienceLogo logo}}

@bold{Humans first in AI science.}

@bold{Human-centered scientific workflows in the AI era.}

@seclink["about-citation"]{About and citation}

@(if release-tag
     (para (hyperlink (string-append "https://github.com/ScienceLogo/Language/tree/" release-tag)
                      release-tag))
     '())

ScienceLogo is a Logo-inspired language for describing scientific workflows that people
can read and inspect. It aims to keep the purpose, structure, assumptions,
and conditions of a method understandable to people, including when AI
participates. Compact and verbose syntax express the same language and can
be mixed in one file.

@bold{Using this manual}

Start with @secref["getting-started"], then use @secref["reference"] to find
a form or naming rule. The remaining pages move from values and procedures to
stages, propositions, uncertainty descriptions, data sources and storage,
reusable definitions, and declared checks. @secref["verbose-syntax"] explains
the equivalent spellings; @secref["compact-grammar"] collects the reference
grammar and parsing rules.

The @hyperlink[(source-file-url "spec/README.md")]{specification index}
groups the language contracts and separates them from design rationale and
earlier notes. Those notes explain the project's development; they do not
add language rules.

@bold{Reference implementation}

The Racket package provides a reader, a core interpreter, and a structural
assessor. The reader validates source and preserves a model of the written
method. The interpreter evaluates values, procedure calls, assignments,
branches, and loops. Paired stages describe work and its entry and exit
state; their bodies are read and checked without being executed. Data
source and storage assignments describe transfers without performing them.

The structural assessor checks declared calls, stage order, workflow parts,
and record requirements. Scientific assessments of protocol conformance,
bias, or uncertainty belong to independent applications using the language.
@secref["assessment"] explains the information available to those applications
and the scope of the package's structural checks.

@include-section["getting-started.scrbl"]
@include-section["reference.scrbl"]
@include-section["verbose.scrbl"]
@include-section["grammar.scrbl"]
@include-section["values.scrbl"]
@include-section["procedures.scrbl"]
@include-section["stages.scrbl"]
@include-section["propositions.scrbl"]
@include-section["uncertainty.scrbl"]
@include-section["resources.scrbl"]
@include-section["interfaces.scrbl"]
@include-section["libraries.scrbl"]
@include-section["assessment.scrbl"]
@include-section["about.scrbl"]
