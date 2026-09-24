# Knowledge synthesis: LLMs with accountable roles

This sketch asks whether published studies find that urban trees reduce summer air
temperature. The LLM suggests screening and extraction decisions; a human handles uncertain
screening and verifies extracted findings. Named agent setups show what each model can read,
which tools it can use, and how its memory is scoped. The syntax is provisional and cannot
yet be run.

```text
investigate "Do urban trees reduce summer air temperature?" [
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

  search "OpenAlex" for "urban trees AND summer air temperature"
  record search query, source, date, and returned records
  remove duplicate records

  to screen paper [
    ask agent "paper screener" about paper
    if unsure [ ask human "decide eligibility" ]
    record final decision, reason, and decision maker
  ]

  for each paper [ screen paper ]

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
  must screen before extracting
  must record a reason and source passage for every screening decision
  must send every unsure screening decision to a human
  must record the resolution of every unavailable full text
  must link every extracted finding to its source passage
  must not carry agent memory from one paper to the next
  must record actual model, prompt, settings, and supplied context for each agent use
  must record tool calls, results, attempts, and stopping reasons for each agent use
  must show missing values and included papers without extracted findings in the synthesis
]
```

The named criteria and fields make the agents' tasks visible. The model and settings names
are provisional parameter slots; a run must identify the actual models, versions, and
settings. A first validator should check that referenced criteria, fields, and
agents are declared, and inspect the ordering rule. A run checker should detect an uncertain
decision without human review, a finding without a source passage, or an undeclared tool use.
Human review is still needed to judge whether passages actually support the decisions and
findings.

The investigation also has state beyond either agent: each paper can be found, screened,
included or excluded, awaiting full text, and extracted. The agent sees only the material
its setup permits at a given point; the run record must show which material it actually saw.

A later version should repeat the synthesis with narrow and broad inclusion criteria, then
compare the conclusions. That tests how the language represents alternative choices and
possible selection bias without losing the decisions made in each run.
