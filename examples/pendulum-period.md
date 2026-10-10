# Pendulum period: the young Galileo test

The research question is: **How does the length of a pendulum affect its period?** The
[runnable method](pendulum-method.rkt) prints a timing plan using the ScienceLogo
syntax available today. It does not measure motion or calculate a period.

A fuller workflow would choose at least two lengths, time a stated number of full
swings at each length, repeat the timings, and compute each period as elapsed time
divided by the number of swings. Each timing record needs the pendulum identity,
length and length unit, swing count, elapsed time and time unit, trial identity, and
the person or instrument that made the timing. The method should state how the
pendulum is released and which conditions are held comparable across trials.

The first assessment question is structural: **were those inputs, records, and
checks specified?** A run assessment then asks which timings occurred and whether
the required fields and evidence were retained. A recorded duration without a time
unit violates the record rule. A specified timing with no observed event remains
undetermined as an occurrence; the method alone cannot show that it happened.
Hand timing can be declared as an uncertainty source and traced into the computed
period and comparison. The language should report that source as declared or
omitted. Its magnitude or scientific importance needs further method and evidence.

The progression can add repeated trials, variation across timings, a changed
release angle, a second timer, and comparison with a proposed relationship between
length and period. An AI assistant could suggest an interpretation, but its input
timings, prompt, model, output, and human review would need separate records. The
scientist's accepted conclusion remains distinct from the assistant's suggestion.

The current reader has no syntax for measurements, repetition, scientific units,
uncertainty, or observed run events. This page states the design test for those
features; the [semantic trace](../spec/core.md#trace-1-timing-a-pendulum) gives
concrete expected outcomes.
