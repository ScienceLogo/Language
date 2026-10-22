# Pendulum period: the young Galileo test

The first research question is: **Does a pendulum's period change as its swing
gets smaller?** The young scientist might expect each swing to become faster.
The discovery to investigate is that the period remains approximately constant
as the swing diminishes. This is the observation associated with Galileo's
[pendulum isochronism](https://catalogue.museogalileo.it/indepth/IsochronismPendulum.html).
The approximation is especially good for small swings
([OpenStax](https://openstax.org/books/university-physics-volume-1/pages/15-4-pendulums)).
The question of how **length** affects the period can follow.

The [runnable method](pendulum-method.rkt) prints a timing plan at
different lengths. It does not measure
motion, calculate a period, or enact the fuller investigation below.

## The investigation across stages

Each stage starts and ends with a complete declared state. Its `information`,
`environment`, and `factors` sets show what was available and what changed. A
`hypotheses` collection within `information` keeps claims distinct from
observations without requiring a fourth set in every workflow. The findings
below illustrate a possible recorded investigation; the written method alone
does not establish that the measurements took place.

| Stage | Information | Environment | Factors considered |
| --- | --- | --- | --- |
| Propose | Question; the initial hypothesis that a smaller swing has a noticeably shorter period; a plan to count full swings. | A pendulum with fixed length, a timer, and a release setup. | Timer resolution and human reaction time. |
| Observe | Angles and timing results enter named locations; periods are derived from elapsed time and swing counts. The hypothesis remains on record. | The same pendulum and timing setup, with the swing angle decreasing. | Reaction time and change of angle during a group of swings. |
| Compare | A comparison refers to the recorded periods and reports no detectable shortening at the stated precision. The initial hypothesis is marked unsupported by these observations, not erased. | The setup used for the comparison remains identified. | Limits of the timing and angle measurements remain visible. |
| Revise | A new hypothesis says the period is approximately constant as the swing diminishes within the observed range. It refers to the earlier claim and the comparison. A later investigation can ask how length affects the period. | The setup for the next test is stated anew. | Influences relevant to that next test are reconsidered. |

In this investigation, a call to time swings reads its named inputs from locations
such as `information.swing-count` and `environment.timer`, then returns a
timing to a location such as `information.elapsed`. A period calculation reads
that result and returns to `information.period`. A comparison reads the periods
and returns its finding to a named location. Internal counters can remain
local. The [stage-call syntax](../spec/stage-state.md#location-based-calls)
lets the reader check these location mappings; the interpreter does
not perform the described measurements.

## A following question: pendulum length

After examining shrinking swings, the investigation can ask how pendulum length
affects period. A fuller workflow would choose at least two lengths, time a
stated number of full swings at each length, repeat the timings, and compute
each period as elapsed time divided by the number of swings. Each timing record
needs the pendulum identity, length and length unit, swing count, elapsed time
and time unit, trial identity, and the person or instrument that made the timing.
The method should state how the pendulum is released and which conditions are
held comparable across trials.

A structural assessment asks: **were those inputs, records, and
checks specified?** A run assessment then asks which timings occurred and whether
the required fields and evidence were retained. A recorded duration without a time
unit violates the record rule. A specified timing with no observed event remains
undetermined as an occurrence; the method alone cannot show that it happened.
Hand timing can be declared as an uncertainty source and traced into the computed
period and comparison. The language should report that source as declared or
omitted. Its magnitude or scientific importance needs further method and evidence.

The progression can add repeated trials, variation across timings, other swing
angles, a second timer, and comparison with a proposed relationship between
length and period. An AI assistant could suggest an interpretation, but its input
timings, prompt, model, output, and human review would need separate records. The
scientist's accepted conclusion remains distinct from the assistant's suggestion.

The current reader accepts declared stage state, but has no syntax for actual
measurements, scientific units, uncertainty, or observed run events. This page states the design
test for those features; the [semantic trace](../spec/core.md#trace-1-timing-a-pendulum)
gives concrete expected outcomes.
