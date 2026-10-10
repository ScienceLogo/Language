#lang sciencelogo

; ScienceLogo describes its own parser and assessor as an investigation.
workflow "How does ScienceLogo assess ScienceLogo?"
implements "requirements/assessor.rkt" as assessor [
  provide parse by "../../private/reader.rkt"
  provide resolve-libraries by "../../private/reader.rkt"
  provide check-interfaces by "../../assessor.rkt"
  provide trace-impacts by "../../assessor.rkt"
  provide report by "../../assessor.rkt"
]
