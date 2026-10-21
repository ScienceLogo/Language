#lang sciencelogo
workflow "Describe a timing before it is available"

interface "Timing" [
  must [period is number unit = "seconds"]
]

interface "Experiment" [
  must [timing = unknown Timing]
]

experiment = Experiment.[]
print experiment.timing == unknown

experiment.timing = Timing.[period = 2]
experiment implement Experiment
print experiment.timing.period
