#lang sciencelogo
workflow "A pendulum timing calculation"
about "Compute a period from an elapsed time and a swing count."

to estimate-period :duration :swings [
  about "Return the elapsed time divided by the number of swings."
  output :duration / :swings
]

set trial to [
  set duration to 20
  set swings to 10
]
do estimate-period duration of trial swings of trial as period
print period
