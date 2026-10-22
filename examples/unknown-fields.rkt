#lang sciencelogo

workflow "Describe supplied and pending pendulum periods"

interface Timing [
  must [period unit = "seconds"]
]

interface Timing-plan [
  must [period = unknown unit = "seconds"]
]

supplied = Timing.[period = 2]
pending = Timing-plan.[]

supplied implement Timing
pending implement Timing-plan
