#lang sciencelogo

interface Pendulum-protocol [
  version "1"
  must [
    measurement
    documentation [
      must [uncertainty]
      notes
    ]
  ]
  additional-measurements
]
