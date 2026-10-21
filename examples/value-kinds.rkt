#lang sciencelogo
workflow "Describe measured and planned pendulum periods"

interface "Timing" [
  must [period is number unit = "seconds"]
]

interface "Timing-plan" [
  must [period = unknown number unit = "seconds"]
]

measured = Timing.[period = 2]
planned = Timing-plan.[]

measured implement Timing
planned implement Timing-plan
