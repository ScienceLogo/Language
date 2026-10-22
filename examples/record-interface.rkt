#lang sciencelogo

workflow "Check timing records"
interface Timing [must [duration unit = "seconds"]]

trial = Timing.[duration = 2]
trial implement Timing

revised = trial.[unit = "minutes"]
revised implement Timing
revised implement "interfaces/timing.rkt"

print trial.unit
print revised.unit
