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

set trial to Timed-observation but [
  duration = 2
  place = "lab"
  observation = "ten swings"
]
must trial implement Timed-observation
must trial implement Timing
must trial implement Location
print unit of trial
