#lang sciencelogo

; A separate, versioned interface states what this assessor must provide.
interface Assessor-process [
  version "0.1"
  must [
    parse
    resolve-libraries
    check-interfaces
    trace-impacts
    report
  ]

  affects parse check-interfaces
  affects resolve-libraries check-interfaces
  affects check-interfaces trace-impacts
  affects trace-impacts report
]
