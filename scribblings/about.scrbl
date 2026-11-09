#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt" "citation-data.rkt")
@(define repository (hash-ref project-citation "repository-code"))
@(define archive (citation-doi-url project-citation))

@title[#:style (page-style) #:tag "about-citation"]{About and citation}

@section{How to cite ScienceLogo}

Please cite ScienceLogo when using it in research:

@nested[#:style 'inset]{@(citation-text project-citation)}

The @hyperlink[(source-file-url "CITATION.cff")]{CITATION.cff file} provides
the citation metadata for reference managers and other tools.

@section{Authorship}

@(for/list ([person (in-list (hash-ref project-citation "authors"))])
   (define orcid (hash-ref person "orcid" #f))
   (para (citation-author-name person)
         (if orcid (list " · " (hyperlink orcid "ORCID")) '())))

@section{Code and project resources}

@itemlist[
 @item{@hyperlink[repository]{Source code}}
 @item{@hyperlink[(string-append repository "/issues")]{Issues and suggestions}}
 @item{@hyperlink[(source-file-url "spec/README.md")]{Language specifications}}
 @item{@hyperlink[(source-file-url "LICENSE")]{@(hash-ref project-citation "license") license}}
]

@section{Releases and archives}

Browse @hyperlink[(string-append repository "/releases")]{ScienceLogo releases}
for version information and release notes.

Each ScienceLogo release is a language version with a two-part number, such
as @tt{0.2} or @tt{0.3}. A language version is a fixed set of definitions: its
syntax and the workflow model the reader produces. Every change, including
a fix to the implementation or the documentation, is released as a new
language version; there are no patch releases. Packages built on ScienceLogo
can add a patch number to every release, but their first two numbers name
the language version they support: version @tt{0.2.3} of such a package
works with language version @tt{0.2}. Each release tag is @tt{v} followed by the version, such as
@tt{v0.2}. The Racket package catalog offers only the latest release; earlier
releases remain available from their GitHub tags and releases.

@(if archive
     (para "Zenodo archive: " (hyperlink archive (hash-ref project-citation "doi"))
           ". This concept DOI identifies ScienceLogo across versions.")
     '())

When citing a particular release, include its version and use that release's
version DOI to identify the archived software used. A concept DOI identifies
the project across versions; see
@hyperlink["https://zenodo.org/help/versioning"]{Zenodo's DOI guidance}.
