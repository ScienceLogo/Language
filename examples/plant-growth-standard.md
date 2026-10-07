# A reusable standard for the plant-growth investigation

**Status:** semantic test for the language, not executable ScienceLogo syntax. This uses
the [young Galileo investigation](plant-growth.md) without changing its beginner sketch.
The standard below is a teaching example created for ScienceLogo; it makes no claim to
represent an external research protocol.

## One standard, several jobs

A library could provide a versioned plant-growth standard. It can scaffold an
investigation with `Observe` and `Compare` stage headers, provide an optional procedure
for recording heights, and declare conditions to validate the method and check an
observed run. The scientist may choose how to measure and compare, subject to the
conditions that apply.

| ID | Condition | Strength | Assessment target |
| --- | --- | --- | --- |
| PG-1 | An `Observe` stage precedes a `Compare` stage on the specified path. | Required | Method structure. |
| PG-2 | Every recorded height retains its plant, value, date, and unit. | Required | Observed run and its measurement records. |
| PG-3 | Keep water and soil comparable between the light groups, and record how. | Recommended, high priority | Method plan and run evidence. |

These conditions belong to the standard in library source. Their IDs, wording, strength,
scope, and required evidence should be inspectable. An implementation still needs syntax
for declaring the standard, importing it, applying it to a study, and encoding each
condition in a checkable form. A small candidate for the declaration reads:

```text
standard "Plant growth" [
  version "0.1"
  must stages in order ["Observe" "Compare"]
  must every recorded height has [plant value date unit]
  should keep water and soil comparable between light groups and record how
]
```

The first list makes both stages and their order required; the second lists fields that
each recorded height must have, with no ordering requirement. A separate candidate
`must all [ ... ]` could group independent required conditions without ordering them.
The `stage` headers in a concrete workflow remain labels. The `should` line expresses
advice. The table also gives PG-3 high priority; syntax for rule IDs, priorities, and
applying the standard is still open. This sketch illustrates the intended distinction
without fixing its grammar.

## Apply it to a concrete study

Suppose a scientist links the standard to an investigation and adds two stage headers
around the calls in the beginner example. This is a candidate for how the parts could
read together, not executable syntax:

```text
investigate "Does light change plant growth?" [
  use standard "Plant growth" version "0.1"
  to measure-plants [
    repeat 7 days [
      measure height
      record height and date
    ]
  ]
  stage "Observe"
  do measure-plants
  stage "Compare"
  do compare "plants in sunlight" with "plants in shade"
]
```

The procedure `measure-plants` remains reusable; the stage headers label the two parts
of this investigation. `use standard` identifies the specification the scientist wants
this method assessed against; it does not claim the method or a future run conforms.
The resolved library source and exact standard version must be retained with the method.
The same standard can assess another study using different measurement or comparison
procedures. The first method satisfies PG-1 when those stage headers are on its specified
path.
This says nothing yet about whether a run recorded complete observations.

A separate assessment operation can inspect a method before execution and an identified
run afterward. One possible reading is `assess method "Does light change plant growth?"
with standard "Plant growth"` and later `assess run plant-run-1 with standard "Plant
growth"`. These are requests for structured findings, not yes/no declarations. An
assessment of a run also needs the exact method version used for that run. An
investigation may link more than one standard; each produces its own findings.

If a later version of this teaching standard changes PG-2's required fields, it does not
change an assessment already made under version `0.1`. The scientist can request a new
assessment under the later version and compare the findings. Both assessments need to
identify the exact standard version and source they used; the shared label `PG-2` alone
does not prove the rule had the same meaning in both versions.

Imagine a run in which day three has a height but no date. The comparison still occurs,
and no record says how watering and soil were kept comparable. Applying the standard to
this method and run should produce findings like these:

| Condition | Finding | Evidence or gap |
| --- | --- | --- |
| PG-1 | Satisfied for the method. | Both named stages appear in order on the specified path. |
| PG-2 | Violated for this run. | The day-three height lacks a date; the other recorded heights remain inspectable. |
| PG-3 | Undetermined, with high-priority advice to document the setup. | The run has no water or soil comparison record; absence of a record does not prove unequal treatment. |

If `Compare` were absent from the specified method, PG-1 would instead fail before a run.
If a future run contained complete measurements, PG-2 could be satisfied for that run
without changing the standard. An assessment should name the standard version, method
version, run, condition IDs, and evidence behind each finding. A summary may be useful,
but it must preserve these separate outcomes.

## Language questions exposed by this test

- How does a library declare and export a standard, its default procedures, and stable
  condition IDs?
- How should `use standard` resolve and lock a library source, and should `assess` be
  the generic operation for method, run, and report assessments?
- How does a standard leave stage bodies open while still requiring stage presence,
  order, and evidence through explicit rules?
- How are recommended conditions and priorities written so they can be checked and
  reported without treating advice as a conformance failure?

The [semantic core](../spec/core.md#standards-as-workflow-specifications) supplies the
broader contract. This example is a concrete target for a first validator and run
checker once the minimal syntax is agreed.
