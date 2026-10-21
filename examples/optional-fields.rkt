#lang sciencelogo
workflow "Describe optional timing details"

interface "Review" [
  must [reviewer is text]
]

interface "Timing" [
  must [period is number]
  notes is text
  review is Review
]

trial = Timing.[period = 2]
print notes in trial

trial.notes = "Timed by hand"
trial.review = [reviewer = "researcher"]
trial implement Timing
print trial is Timing
