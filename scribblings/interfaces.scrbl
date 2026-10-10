#lang scribble/manual
@(require "site-head.rkt" "site-links.rkt")

@title[#:style (page-style) #:tag "interfaces"]{Structural assessment}

An interface can state which named parts a particular method must provide and how
an omission may affect later parts. This is a structural check, not a judgment of
scientific adequacy.

The @hyperlink[(source-file-url "examples/meta-assessor/requirements/assessor.rkt")]{assessor interface}
is a separate @tt{#lang sciencelogo} file. It has one version and five required
parts:

@verbatim|{
#lang sciencelogo

interface "ScienceLogo assessor" [
  version "0.1"
  require parse
  require resolve-libraries
  require check-interfaces
  require trace-impacts
  require report

  affects parse check-interfaces
  affects resolve-libraries check-interfaces
  affects check-interfaces trace-impacts
  affects trace-impacts report
]
}|

The @hyperlink[(source-file-url "examples/meta-assessor/method.rkt")]{complete investigation}
references that file and supplies an implementation reference for each part:

@verbatim|{
#lang sciencelogo

investigate "How does ScienceLogo assess ScienceLogo?" [
  implements "requirements/assessor.rkt" as assessor [
    provide parse by "../../private/reader.rkt"
    provide resolve-libraries by "../../private/reader.rkt"
    provide check-interfaces by "../../assessor.rkt"
    provide trace-impacts by "../../assessor.rkt"
    provide report by "../../assessor.rkt"
  ]
]
}|

Run this from an installed checkout:

@verbatim|{
racket -l sciencelogo/assessor -- examples/meta-assessor/method.rkt
racket -l sciencelogo/assessor -- examples/meta-assessor/missing-impact.rkt
}|

The first command reports no structural issues. The second uses an incomplete
investigation: it reports missing @tt{trace-impacts} and marks @tt{report} as
affected through the declared @tt{affects} link. It exits with status 1.

The interface path is relative to the investigation file. A @tt{provide} reference
is a claim, not proof that the named work exists or is correct; the assessor does
not inspect those references. The five names belong to this interface. ScienceLogo
does not require every workflow activity or item to have an author-written name.
Interface versions appear in the report, but this assessor does not compare them.
