#lang sciencelogo

; A separate, versioned interface states what this assessor must provide.
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
