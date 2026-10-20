#lang sciencelogo

workflow "Describe a pendulum trial"
interface "Timed-observation" [
  extends Timing
  extends Location
  must [observation unit = "minutes"]
]
interface "Timing" [must [duration unit = "seconds"]]
interface "Location" [must [place]]

trial = Timed-observation.[
  duration = 2
  place = "lab"
  observation = "ten swings"
]
trial implement Timed-observation
trial implement Timing
trial implement Location
print trial.unit
