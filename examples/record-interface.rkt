#lang sciencelogo

workflow "Check timing records"
interface "Timing" [duration unit = "seconds"]

trial = Timing.[duration = 2]
must trial implement Timing

revised = trial.[unit = "minutes"]
must revised implement Timing
must revised implement "interfaces/timing.rkt"

print trial.unit
print revised.unit
