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

A version number has three parts, such as @tt{0.2.1}. The first two,
@tt{0.2}, name the language version: its syntax and the workflow model the
reader produces. A change to either starts a new language version. The third
part marks refinements, such as fixes and documentation, that change neither.
Workflows and tools written for language version @tt{0.2} work with every
@tt{0.2} release. Racket omits a third part of zero, so the first release of
@tt{0.2} is written @tt{0.2}.

@(if archive
     (para "Zenodo archive: " (hyperlink archive (hash-ref project-citation "doi"))
           ". This concept DOI identifies ScienceLogo across versions.")
     '())

When citing a particular release, include its version and use that release's
version DOI to identify the archived software used. A concept DOI identifies
the project across versions; see
@hyperlink["https://zenodo.org/help/versioning"]{Zenodo's DOI guidance}.
