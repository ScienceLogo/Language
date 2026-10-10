# Knowledge synthesis: LLMs with accountable roles

This sketch asks whether published studies find that urban trees reduce summer air
temperature. The LLM suggests screening and extraction decisions; a human makes each final
screening decision and verifies extracted findings. Named agent setups show what each model
can read, which tools it can use, and how its memory is scoped. The syntax is provisional
and cannot yet be run.

```text
workflow "Do urban trees reduce summer air temperature?"
criteria "eligible studies" [
  include measured outdoor summer air temperature
  include a comparison of places with different tree cover
]
fields "extraction" [
  location
  study dates
  temperature difference
  measurement method
]

prompt "screen-v1" [
  instruction "Apply the criteria to the supplied paper text."
  context criteria "eligible studies"
  context title and abstract of current paper
  question "Include, exclude, or unsure? Give a reason and source passage."
  answer [ decision, reason, source passage ]
]
settings "screen-settings" [ output limit 300 tokens ]

prompt "extract-v1" [
  instruction "Extract only what the supplied full text supports."
  context fields "extraction"
  context full text of current paper
  question "What does this paper report for each field?"
  answer [ value or missing, source passage for each value ]
]
settings "extract-settings" [ output limit 800 tokens ]

agent "paper screener" [
  role "suggest whether one paper meets the criteria"
  given criteria "eligible studies"
  given title and abstract of current paper
  model "screen-model"
  settings "screen-settings"
  prompt "screen-v1"
  environment [
    tools none
    memory none between papers
    stop after one suggestion
  ]
  suggest include, exclude, or unsure with a source passage
]

agent "paper extractor" [
  role "suggest temperature outcomes and study conditions"
  given fields "extraction" and full text of current paper
  model "extract-model"
  settings "extract-settings"
  prompt "extract-v1"
  environment [
    may use tool "search supplied full text"
    memory none between papers
    stop after fields returned or one failed attempt
  ]
  suggest values, missing values, and source passages
]

ask human "approve or revise eligibility criteria and extraction fields"
record reviewed criteria, fields, decision, and reviewer
require criteria and fields approved
search "OpenAlex" for "urban trees AND summer air temperature"
record search query, source, date, and returned records
remove duplicate records

to screen-paper :paper [
  ask agent "paper screener" about :paper
  if unsure [ ask human "resolve uncertain eligibility" ]
  if include or exclude [ ask human "confirm or revise eligibility" ]
  if invalid or no answer [ ask human "resolve failed screening" ]
  record final decision, reason, and decision maker
]

for each paper [ do screen-paper paper ]

for each included paper [
  obtain full text
  if unavailable [
    record "full text unavailable"
    ask human "resolve missing full text"
    record resolution
  ]
  if available [
    ask agent "paper extractor" about paper
    if failed [ ask human "resolve failed extraction" ]
    ask human "verify extracted findings"
    record corrections and final extracted findings
  ]
]

synthesize verified findings
ask human "review synthesis against verified findings"
record reviewer, reasons, and corrections
record final conclusions linked to verified findings
must approve criteria and fields before screening
must screen before extracting
must record a reason and source passage for every screening decision
must send every unsure screening decision to a human
must record a human decision before every final eligibility decision
must record the resolution of every unavailable full text
must link every extracted finding to its source passage
must link every final conclusion to verified findings
must review synthesis before recording final conclusions
must record reviewer, reasons, and corrections before final conclusions
must keep agent suggestions distinct from verified findings and final conclusions
must not carry agent memory from one paper to the next
must reject context or tool use outside each agent's declared environment
must retain every agent attempt, including failed or discarded answers
must record actual model, prompt, settings, and supplied context for each agent use
must record tool calls, results, attempts, and stopping reasons for each agent use
must show missing values and included papers without extracted findings in the synthesis
```

The named criteria, fields, prompts, and settings make the agents' tasks visible. The model
names are provisional parameter slots; a run must identify the actual models, versions, and
effective settings. A first validator should check that referenced criteria, fields,
prompts, settings, and agents are declared, and inspect the ordering rule. A run checker
should detect an uncertain decision without human review, a finding without a source
passage, or an undeclared tool use.
Human review is still needed to judge whether passages actually support the decisions and
findings.
The criteria review and final synthesis review make supervision visible at the start and end
of the investigation as well as for each paper. `require` blocks the search until criteria
and fields are approved; the `must` rules let a checker inspect whether those reviews and
source links were recorded. A recorded approval is evidence of a decision, not proof that
the resulting scientific conclusion is correct.

The investigation also has state beyond either agent: each paper can be found, screened,
included or excluded, awaiting full text, and extracted. The agent sees only the material
its setup permits at a given point; the run record must show which material it actually saw.

A later version should repeat the synthesis with narrow and broad inclusion criteria, then
compare the conclusions. That tests how the language represents alternative choices and
possible selection bias without losing the decisions made in each run.
