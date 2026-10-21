#lang sciencelogo
workflow "Reuse a timing interface"

interface "Timing" [
  must [period is number unit = "seconds"]
]

interface "Experiment" [
  must [timing is Timing]
]

timing = Timing.[period = 2]
experiment = Experiment.[timing = timing]
experiment implement Experiment

if experiment.timing is Timing [print experiment.timing.period]
