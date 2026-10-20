#lang sciencelogo

workflow "Document a pendulum measurement"
include "interfaces/pendulum-protocol.rkt"

performer researcher [kind = "human"]

"Timing" implement Pendulum-protocol.measurement

stage "Timing" by researcher from state [
  information = [period = 2 u [declared = [timing = [estimate = 0.1 unit = "seconds"]]]]
]
  information.period.u implement Pendulum-protocol.documentation.uncertainty
end stage with state [
  information = [period = 2 u [declared = [timing = [estimate = 0.1 unit = "seconds"]]]]
]
