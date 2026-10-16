#lang sciencelogo

workflow "Describe a pendulum trial"
interface "Timed-observation" [
  extends Timing
  extends Location
  observation
  unit = "minutes"
]
interface "Timing" [duration unit = "seconds"]
interface "Location" [place]

trial = Timed-observation.[
  duration = 2
  place = "lab"
  observation = "ten swings"
]
must trial implement Timed-observation
must trial implement Timing
must trial implement Location
print trial.unit
