#lang sciencelogo

workflow "Check timing records"
interface "Timing" [duration unit = "seconds"]

set trial to Timing but [duration = 2]
must trial implement Timing

set revised to trial but [unit = "minutes"]
must revised implement Timing
must revised implement "interfaces/timing.rkt"

print unit of trial
print unit of revised
