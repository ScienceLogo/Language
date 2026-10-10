# Rainfall modelling: proposals, evaluation, and alternatives

This sketch asks whether rainfall can predict next-day river flow. The LLM proposes extra
predictors, while fitting and evaluation remain explicit parts of the workflow. The syntax
is provisional and cannot yet be run.

```text
workflow "Can rainfall predict tomorrow's river flow?"
obtain daily rainfall observations
obtain daily river-gauge observations
align observations by date
mark missing values
split earlier years for training and the final year for testing
choose missing-value treatment using training data
apply chosen treatment to training and test data

fit "rainfall-only baseline" on training data

llm "propose extra predictors" [
  role "suggest candidate variables and explain why they may help"
  read research question, available measurements, and training summary
  use prompt "predictors-v1"
  record proposal and reasons
]
ask human "approve or reject the proposal"
if approved [ fit "candidate model" on training data ]

evaluate each fitted model on test data
compare prediction errors with the baseline
report result and uncertainty

must split data before fitting or proposing predictors
must keep test outcomes out of the llm context
must record model, prompt, settings, and supplied context for the llm proposal
must record the approved and rejected proposals with reasons
must record data versions, missing-value treatment, transformations, code, settings, and fitted parameters
must link every reported result to its model and evaluation data
```

The baseline makes the effect of an LLM suggestion visible. The final year provides held-out
evaluation data. Checking the actual transformations and LLM context is needed to detect
leakage into model selection. The workflow must retain the prompt and the actual context
supplied to the LLM, because a declared intent to hide test outcomes is not evidence that a
particular run did so.

A first validator can inspect the order of split and fit operations and the declared inputs
to the LLM. A run checker must inspect the data and context actually supplied. Scientific
judgment is still required to assess the measurements, modelling assumptions, and meaning
of the reported uncertainty.
