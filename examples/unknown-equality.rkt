#lang sciencelogo
workflow "Describe known and unknown pendulum periods"

interface "Timing" [
  must [period = unknown number]
  if period == unknown [
    must [reason]
  ] else [
    must [period > 0]
  ]
]

pending = Timing.[reason = "Measurements are pending"]
measured = Timing.[period = 2]

pending implement Timing
measured implement Timing
