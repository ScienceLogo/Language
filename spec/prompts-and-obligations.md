# Prompts and obligations (draft)

**Status:** design proposal, not adopted syntax or an executable language. This develops the
[semantic core](core.md) using the [knowledge-synthesis example](../examples/knowledge-synthesis.md).

## Which words declare, and which words act?

`must` is the proposed **obligation declaration**. It says what a workflow or run is required
to do or preserve. It does not perform an action when execution reaches that line. For
example, `must send every unsure screening decision to a human` requires a check; `ask human`
is the action that may satisfy it. A procedure can take another path, fail, or be interrupted,
so writing the `ask` action alone cannot establish that the obligation held in a run.

`must` is not the only declarative word. `criteria`, `fields`, `prompt`, `settings`, and
`agent` name parts of the method. Their names can be referenced by procedures. `to` names a
procedure; its commands, including `ask`, `if`, and `for each`, specify possible actions and
order. Nesting scopes names and rules to the investigation or procedure that contains them.
An obligation inside a procedure applies to each call of that procedure; one in an
investigation applies across its relevant activities.

### A small vocabulary for conditions

These forms have different jobs. Their exact spelling is still open, but a prototype should
preserve the distinctions:

| Form | Meaning | When it is checked |
| --- | --- | --- |
| Named declaration, such as `prompt` or `criteria` | Introduce a named method item, its structure, and its references. Declaring a claim does not establish its truth. | Validate its structure and references before a run. |
| `require condition` | Guard the sequence at this point. If false or unknown, suspend later actions in that sequence and record why; a specified resolution path may supply missing evidence. | When execution reaches the gate, with a check event in the run. |
| `must rule` | State an obligation over the containing scope, including later paths and outcomes. It does not itself advance the procedure. | At its declared checkpoint, using static analysis, run evidence, or human review as appropriate. |
| `check condition` | Ask for an immediate evaluation and retain the result and evidence. This is an activity in the sequence. | Exactly where the command appears in a run. |

`declare` could be a general spelling for introducing a named item, but `prompt "screen-v1"`
and `criteria "eligible studies"` are shorter and tell a reader what kind of item is being
introduced. A future `declare` form needs a concrete use that these named forms cannot
express. `assert` could name the immediate test, but it can also sound like a claim is being
pronounced true. `check` better invites a **satisfied**, **violated**, or **undetermined**
answer. If `assert` is ever added, it must have an explicit checking meaning and recorded
evidence; it must not promote a model suggestion to scientific fact.

For example, a procedure may say `require full text of paper is available` before it asks
an extractor, then `check every suggested finding has a source passage` after the answer.
A surrounding `must every verified finding links to its source passage` still applies if the
procedure fails, is skipped, or follows another path. The check event says what was tested
in this run. The `must` rule says what every applicable run owes. A failed or undetermined
`require` needs an explicit handoff or stop; a failed `check` needs its result handled or
retained as a violation, according to the containing procedure's policy.

The readable text after `must` cannot be arbitrary prose if the language promises a check.
The first parser should support a small, explicit grammar for relations such as `before`,
`has`, `from`, and `when`. A sentence outside that grammar must be rejected or marked as a
human assessment, never silently treated as a verified rule. Each parsed obligation needs:

| Part | Meaning |
| --- | --- |
| Scope and subject | Which papers, activities, decisions, or runs the rule covers. |
| Trigger | When the rule applies, such as an agent returning `unsure`. |
| Required condition | The order, value, provenance, or human action required. |
| Checkpoint | When to evaluate it, such as before a final decision or at the end of a run. |
| Evidence | The item fields and run events needed to report satisfied, violated, or undetermined. |

For example, `must when screening suggestion is unsure [ human decision before final
decision ]` is a scoped rule. A checker can verify that the named events occurred in order
for each affected paper. It cannot decide whether the human's scientific judgment was good.
The proposed `must` form may also contain a nested group of such rules. A simple beginner's
rule remains one line: `must record a date for every height`.

## A prompt is a named method component

An LLM prompt needs a stable name and revision, ordered instruction and task parts, named
input slots, and an expected answer shape. In a simple workflow, these can read like ordinary
instructions. A more detailed workflow can declare message roles, content kinds, examples,
and tool descriptions. The language should preserve the order and structure of all these
parts; it should not reduce the prompt to one opaque string. The exact wire format and role
mapping belong to the chosen model adapter and must be visible in the run record.

The following is a syntax sketch for one screening prompt. `context` inserts the named
material into the request at that position; it is not permission to read other material.
The agent setup separately defines what material is permitted. The answer shape states a
required format that a checker can inspect; it does not prove the answer is true.

```text
prompt "screen-v1" [
  instruction "Apply the supplied eligibility criteria to this paper."
  context criteria "eligible studies"
  context title of current paper
  context abstract of current paper
  question "Include, exclude, or unsure? Give a reason and a source passage."
  answer [
    decision one of include, exclude, unsure
    reason text
    passage from supplied title or abstract
  ]
]

settings "screen-settings" [
  output limit 300 tokens
]

agent "paper screener" [
  given criteria "eligible studies"
  given title and abstract of current paper
  model "screen-model"
  settings "screen-settings"
  prompt "screen-v1"
  suggest a screening decision
]

to screen paper [
  ask agent "paper screener" about paper
  if unsure [ ask human "resolve uncertain eligibility" ]
  if include or exclude [ ask human "confirm or revise eligibility" ]
  if invalid or no answer [ ask human "resolve failed screening" ]
  record final decision
  must when screening suggestion is unsure [
    human decision before final decision
  ]
  must human decision before final decision
  must final decision has reason, decision maker, and source passage
]
```

The prompt name, settings name, criteria name, and agent name are references, so a validator
can reject an unknown name, a missing input, or a prompt that asks for context outside the
agent's allowed view. Names such as `screen-model` can be experiment parameters, but they
must resolve to a provider, concrete model identity or version, and supported options before
an agent call. Unsupported settings should be reported instead of ignored. Model parameters
belong to `settings`, not inside the prompt text; tools, memory, retrieval, retries, and
stopping rules belong to the agent's working environment.

## What the run must retain

The named template is distinct from the **request actually sent**. Each agent call should
retain the resolved prompt revision and digest; bound slot values with source identities and
versions; ordered rendered messages and content parts; the actual model and adapter; all
resolved parameters, including adapter defaults; and the tools and permissions supplied.
If material is retrieved, shortened, omitted, or added by a tool or memory, record what the
model actually received and the decision that selected it. Later turns, tool calls and
results, retries, responses, validation failures, and stopping reasons belong to the same
trace. Where a provider cannot expose some internal behavior, mark it unknown.

Some source material may be access restricted. A run can retain a protected copy or a
controlled reference and digest, plus its provenance and access rule; a digest alone cannot
let a reviewer inspect the content. The run must never imply that the model saw the whole
investigation simply because the investigation contained it.

Checks happen at different times. Before a run, a validator can resolve names, confirm
input slots, inspect declared permissions, and check some possible ordering paths. During
or after a run, a checker can inspect actual context, event order, output fields, and human
handoffs. A scientific claim that a passage supports an answer requires human assessment
unless a specific accepted test exists. All checks report **satisfied**, **violated**, or
**undetermined** with their evidence, as defined in the [semantic core](core.md).
