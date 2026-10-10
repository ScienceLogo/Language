#lang sciencelogo

; This runnable slice prints a timing plan. It does not time a pendulum.
workflow "How does length affect a pendulum's period?"
do [
  do make-timing-plan as plan
  print plan
]

to make-timing-plan [
  output "Time ten swings at each length, repeat, and record each duration with its unit."
]
