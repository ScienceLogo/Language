#lang sciencelogo

workflow "Describe a series of pendulum measurements"

interface "Timing-series" [
  must [measurements.count >= 3]

  for each measurement in measurements [
    must [measurement.period measurement.period.u]
  ]
]

series = Timing-series.[
  measurements = [
    [period = 2 u [declared = [timing = [estimate = 0.1 unit = "seconds"]]]]
    [period = 2.1 u [declared = [timing = [estimate = 0.1 unit = "seconds"]]]]
    [period = 2 u [declared = [timing = [estimate = 0.1 unit = "seconds"]]]]
  ]
]

series implement Timing-series
