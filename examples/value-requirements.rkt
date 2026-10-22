#lang sciencelogo

workflow "Describe a pendulum timing trial"

interface Timing-trial [
  must [swing-count > 10 swing-height unit == "seconds"]
]

trial = Timing-trial.[swing-count = 20 swing-height = 0.1 unit = "seconds"]
trial implement Timing-trial
