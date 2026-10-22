# Descriptions of workflows, stages, and procedures

The reader and workflow model preserve `about` descriptions. Descriptions
do not affect execution or structural checks. Publication tools
can use them; the language package does not generate research booklets.

## Form and attachment

`about "text"` attaches an optional CommonMark Markdown description to one
workflow, stage, or procedure. It uses an ordinary quoted string, which may
span lines. Existing string escapes apply; no triple quotes are needed.

```text
#lang sciencelogo
workflow "Review a timing plan"
about "Explain how to time a pendulum as the swing gets smaller."

stage Prepare
about "Prepare the timing plan."
do make-plan as plan

to make-plan [
  about "Return a timing plan, with its **purpose**."
  output "Time ten swings as the swing gets smaller."
]

stage Review
about "Read the plan."
print plan
```

| Owner | Placement |
| --- | --- |
| Workflow | At the start of the file, after its optional `workflow "title"` and before imports and method forms. Without a title, `about` may be the first form. |
| Procedure | Immediately inside the opening `[` of its `to` definition, before commands. This also applies to procedures in libraries and included files. |
| Simple stage | Immediately after `stage name`. |
| Paired stage | Immediately after its complete opening header, including its entry `state [...]`, before body commands. |

Each owner has at most one description. Whitespace and comments may separate
the header and description; another command may not. A description belongs
to its attached owner, even when that owner is nested inside another named
part. For example, a stage inside a procedure may have its own description
without replacing the procedure's description.

The paired form follows the same rule:

```text
stage Inspect from state [information = [period = 2]]
about "Inspect the stated period."
end stage with state [information = [period = 2]]
```

`about` is reserved. It is not a general command for anonymous blocks such
as `do [...]`, `if`, or loops, and it does not describe a library or interface
declaration. An included workflow fragment cannot supply the entry workflow's
description. Use comments for local reading notes in those positions.

## Writing descriptions

Descriptions are optional and may be empty. No headings, template, or list of
sections is required. A short opening summary is recommended. Authors may
explain purpose, assumptions, limitations, and how to interpret results.

- A workflow description can summarize its question, scope, and limits.
- A stage description can explain the purpose of its checkpoint or work.
- A procedure description can explain a reusable method and its limitations.
  Its inputs and returned results remain defined by the source code.

Descriptions provide human explanation. A prose claim does not declare a
value, condition, performer, hypothesis, or completed action. Structured
declarations remain the source of those facts. The reader stores Markdown
text without rendering it or checking its scientific claims. It does not
enforce a Markdown layout or resolve links in prose.

## Preserved information

The parsed tree retains an `about` node within the owning workflow, procedure,
or stage. Its text is preserved after ordinary string escape decoding, with
the source location of `about`. Descriptions survive includes and pinned
library imports; imported names are qualified without rewriting prose.

The Racket workflow model exposes `workflow-model-description`,
`stage-model-description`, and `procedure-model-description`. Each returns
`#f` when absent, or a `description-model` with `text` and `source` fields.
The source is a `source-ref`. A present empty string remains distinct from
an absent description. Descriptions do not create activities, value
dependencies, scope boundaries, or assessment conditions.
