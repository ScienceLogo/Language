#lang sciencelogo

workflow "Which pendulum lengths should we compare?"

set lengths to range 0.25 to 1.00 step 0.25

stage "Plan lengths"
for each length in lengths [
  print length
]

stage "Review longer trials"
for each length in lengths [
  if length >= 0.75 [print length]
]
