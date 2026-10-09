#lang sciencelogo

; This deliberately incomplete method tests missing-part and impact findings.
investigate "How does ScienceLogo assess ScienceLogo?" [
  implements "requirements/assessor.rkt" as assessor [
    provide parse by "../../private/reader.rkt"
    provide resolve-libraries by "../../private/reader.rkt"
    provide check-interfaces by "../../assessor.rkt"
    provide report by "../../assessor.rkt"
  ]
]
