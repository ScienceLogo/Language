#lang sciencelogo

workflow "How will we study a pendulum?"
do [
  do introduce
  do finish
]

to finish [
  print "Keep each timing with its length and unit."
]

to introduce [
  print "Time ten swings at each length."
]
