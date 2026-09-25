# LLM variation and context (draft)

**Status:** design contract for LLM activities, not adopted syntax or an executable policy.
Read this with the [semantic core](core.md) and the [prompt and obligation design](prompts-and-obligations.md).

## An LLM answer is an outcome under conditions

An LLM call is an activity with an observed result, not a function that promises the same
answer whenever it is called. Even a low sampling temperature does not guarantee identical
answers for identical requests; [Anthropic's API glossary](https://platform.claude.com/docs/en/about-claude/glossary)
states this explicitly. ScienceLogo must represent each call and answer separately, including
failed, refused, incomplete, and invalid answers. The model's proposed answer begins as a
**suggestion**, with its source and status; a decision or finding requires a further activity
and its own evidence.

Two uncertainties must remain distinct. **Output variation** asks whether another call under
similar conditions might answer differently. **Scientific uncertainty** asks whether the
answer is supported by data and whether the method warrants the conclusion. Agreement among
several generated answers does not establish scientific truth. A model's stated confidence
is a reported output, not a calibrated probability unless the workflow supplies and checks
an appropriate calibration method.

## The conditions of a call

The method should name the conditions that matter to the investigation. Each run must retain
the conditions actually used, at least:

- model provider and resolved identity or version, adapter version, requested settings and
  effective settings, including any seed the provider actually accepts;
- prompt template revision and digest, ordered rendered messages, content kinds, and output
  format request;
- the identity, version, selected passages, order, and status of each supplied source;
- retrieval query, source collection and version, selection rule, selected results, and any
  omission or shortening of context;
- available tools and permissions, each tool call and result, memory supplied or changed,
  earlier turns, retries, and stopping reason; and
- answer, validation results, human edits, selection among attempts, and the reason for that
  selection.

Some providers expose less than this. The trace should say **unknown** where a condition
cannot be observed, and the method should state whether that limit is acceptable. A named
prompt or an allowed context source alone is insufficient evidence of what the model saw.
The [prompt design](prompts-and-obligations.md) separates the template from the rendered
request for this reason.

Context is part of the scientific method. A changed search index, retrieval ranking, chunk
boundary, omitted paragraph, message order, tool result, or remembered conversation can
change the answer. A run must show how context was selected and the exact material actually
supplied, subject to documented access restrictions. Source text should retain its status as
source material; instructions embedded in a paper or web page do not thereby become a
scientist's instructions to the agent.

## Replication and control

An earlier trace can be inspected again without asking the model to regenerate it. A new
run can attempt to repeat the method, using the same declared inputs, prompt revision, model,
settings, context selection, and environment where those are available. It is a new run with
new attempt identities. ScienceLogo should compare the conditions first, then the outputs,
checks, decisions, and scientific conclusions. If a model version or source collection has
changed or cannot be recovered, the comparison must identify that difference. A repeatable
method is an inspectable specification with observable differences across runs; it is not a
promise of identical generated text.
For example, if one screening attempt returns `unsure` and a later attempt returns
`include`, both remain visible with their requests and evidence. The comparison shows
whether the supplied context changed before interpreting the difference in answers.

Control requires checks before and during an agent activity. The implementation should
resolve and validate the model and settings, assemble context only from permitted sources,
enforce tool access and attempt limits, and record the material sent. A `require` condition
can block an activity until its precondition is satisfied or resolved. A `must` rule can
require a human decision before an agent suggestion becomes a final finding. Failed checks,
timeouts, refusals, and exhausted retries follow declared handoff or stopping paths. If an
adapter cannot enforce a requested boundary, the activity should not proceed as though that
boundary were guaranteed.

## A method can prescribe how to handle variation

An investigation should choose a policy appropriate to each LLM activity. A low-risk
teaching example may use one suggestion and inspect it. A screening workflow may ask for
several separately recorded suggestions, compare them, and route disagreement to a human. An
evaluation can use a fixed set of papers with known reviewer judgments, then compare prompt,
model, or context choices. Repeated calls and alternative settings cost time and resources,
so the language should make the choice explicit rather than require the same count in every
workflow.

This is a provisional nested sketch of one such policy:

```text
to screen paper [
  repeat 3 times [
    ask agent "paper screener" about paper with fresh memory
    record suggestion
  ]
  check every suggestion has a decision, reason, and source passage
  if suggestions disagree or any attempt fails or any suggestion is unsure or invalid [
    ask human "resolve eligibility"
  ]
  if all attempts return valid agreeing suggestions [
    ask human "confirm eligibility"
  ]
  record final human decision
]

must for each paper [
  record every attempt, including failed and discarded answers
  record why an answer was selected or rejected
  final decision has a human decision maker and source passage
]
```

The repeated calls must be separate recorded attempts with the declared memory policy.
Three attempts illustrate a procedure; their agreement is not a reliability estimate.
The rule about retaining attempts prevents a workflow from silently showing only a convenient
answer. The human remains responsible for the final decision here; another investigation
could declare a different authority boundary and review policy. The word `check` denotes an
immediate activity; `must` denotes obligations on the whole scoped run.

A checker can test whether the attempts, source links, format fields, and human events exist.
It can also compare actual context and settings with the method. Whether passages really
support decisions, whether criteria are scientifically suitable, and whether the evaluation
set is representative require scientific judgment. A structured answer format helps test
shape but does not guarantee factual correctness; [OpenAI's Structured Outputs guide](https://developers.openai.com/api/docs/guides/structured-outputs)
also notes that structured outputs can contain mistakes. A run should report those limits
instead of claiming that a format check validated the science.

## First prototype checks

The first representation should support multiple attempts for one activity, distinguish
requested from effective settings and allowed from supplied context, and retain all answers
with their validation and selection events. It should reject an undeclared source or tool,
detect gaps when an external request log or attempt count exposes them, and report the
relevant `must` or `require` outcome as satisfied, violated, or undetermined with evidence.
If the run record is incomplete, a checker cannot infer that an unrecorded attempt did not
happen; it must report the completeness limit.
