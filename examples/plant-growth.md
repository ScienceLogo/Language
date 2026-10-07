# Plant growth: the young Galileo test

This beginner sketch asks a question, repeats an observation, and states one evidence rule.
The syntax is provisional and cannot yet be run.

```text
investigate "Does light change plant growth?" [
  to measure-plants [
    repeat 7 days [
      measure height
      record height and date
    ]
  ]

  do measure-plants
  do compare "plants in sunlight" with "plants in shade"
  must record a date for every height
]
```

`to measure-plants` defines the procedure; `do measure-plants` runs it at this point.
The two `do` lines run once, in order. `repeat 7 days` is the loop inside the procedure.

The first lesson is that a measurement and its date belong together. The obligation should
cause a check: a run with an undated height is incomplete, even if the comparison was made.
The language must eventually identify which plant and group each height belongs to, as well
as its unit. Those are parts of the investigation's setting, and a runnable form must make
them visible or ask the learner to supply them. That detail can be introduced as the learner
asks for a fairer comparison.

The same investigation can grow through later lessons: keep water and soil comparable;
record a missed day instead of inventing a height; describe variation across plants; and
show the original observations behind a conclusion. Each addition should remain visible in
the procedure and in the evidence from a run.

An AI-era extension could ask an LLM to suggest descriptions of leaf photographs:

```text
llm "describe leaf photographs" [
  role "suggest observations about visible leaf condition"
  read original photographs
  record model, prompt, settings, and descriptions
]
must keep the original photograph behind every description
must mark each unverified description as a suggestion
```

This extension tests whether the language can distinguish the photograph, the model's
description, and a scientist's accepted observation. It also tests whether a young reader
can still understand who or what made each claim.
