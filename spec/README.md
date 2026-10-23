# ScienceLogo specification guide

The [language manual](../scribblings/sciencelogo.scrbl) provides the learning
path and syntax lookup. It progresses from a small investigation to values,
procedures, stages and state, propositions, uncertainty descriptions, data
sources and storage, interfaces, libraries, and assessment support.

The documents below define the language rules and the behavior of the
reference implementation. Design rationale and earlier exploratory notes
have their own sections; they do not introduce additional language forms.

## Language specification

| Topic | Document and scope |
| --- | --- |
| Compact syntax | [Compact grammar](compact.ebnf), together with the manual's [grouping, placement, and name-resolution rules](../scribblings/grammar.scrbl). |
| Verbose and mixed syntax | [Equivalent spellings and normalization](verbose-syntax.md), including preservation of source locations, comments, and parentheses. |
| Source and core behavior | [Language rules and reference behavior](first-slice.md): files, names, values, procedures, assignments, expressions, control flow, and structural checks. |
| Human explanation | [Descriptions](descriptions.md): optional `about` Markdown attached to workflows, stages, and procedures. |
| Interfaces | [Interface entries](interfaces.md): required and optional entries, defaults, value kinds, unknown permissions, nested parts, inheritance, conditions, and per-item requirements. |
| Libraries and local files | [Libraries](libraries.md): repository layout, pinned imports, includes, and dependency rules. |
| Stages and state | [Paired stages and state locations](stage-state.md): entry and exit state, performers, input and return locations, and declared changes. |
| Context | [Context sets](context.md): the meaning of information, environment, and considered factors within stage state. |
| Hypotheses, assumptions, and conclusions | [Propositions](propositions.md): names, nesting, references, and updates. |
| Uncertainty | [Attached uncertainty descriptions](uncertainty.md): the `u` attachment and its declared and omitted sources. |
| Data outside a workflow | [Data sources and storage](resources.md): `resource` declarations and directional data paths. |
| Reader output | [Shared representation](representation.md): method information and relationships readers must preserve. |
| Language and applications | [Language boundary](architecture.md): the specification, reader, core interpreter, structural assessor, and independent scientific applications. |

## Reference implementation and tools

The Racket reader accepts compact, verbose, and mixed source through one
compact parsing and checking path. The core interpreter evaluates executable
forms. Paired-stage bodies and resource assignments describe the method;
the interpreter does not carry out those stages or transfer external data.
The [assessment support manual](../scribblings/assessment.scrbl) describes
the package's structural checks and the information available to independent
assessment applications.

The public [source conversion API](../normalize.rkt) accepts compact,
verbose, or mixed input and produces compact or verbose source. The
[command-line converter](../translate.rkt) exposes the same operation. The
[workflow model](../workflow-model.rkt) exposes Racket values; the package
does not provide a language-neutral export format. Scientific assessment algorithms and
publication generators belong to independent applications.

## Design rationale

The [design principles](design-principles.md) explain the human-centered purpose,
Logo inspiration, and scientific use cases behind the language. The
specification above defines the syntax and behavior; rationale does not
add requirements to a workflow.

## Earlier design notes

These notes retain earlier exploratory designs and examples. Their wording
and code sketches are not language rules or a development roadmap. Use the
specification and manual for valid source and supported behavior.

| Note | Subject |
| --- | --- |
| [Method, runs, and findings](core.md) | Explorations of scientific context, observed events, and assessment records. |
| [Prompts and obligations](prompts-and-obligations.md) | Earlier sketches of AI requests and broader conditions. |
| [LLM variation and context](llm-variation.md) | Considerations about repeated attempts, supplied context, replication, and control. |
| [Workflow publication](workflow-documentation.md) | Ideas for external research booklets and method/run presentations. The language's `about` form is defined in [Descriptions](descriptions.md). |

## Documentation conventions

For each language form, state its spelling, where it is allowed, what it
means, what the reader checks, and how the reference interpreter handles it.
Use a small example before the full constraints. Give each detailed rule one
home and link to it from other pages. The manual uses one level of pages
with headings within each page.

Use familiar terms consistently: a **stage** is a checkpoint, a **procedure**
is a reusable definition, a **call** invokes one, **state** names what a
paired stage receives and leaves, and a **performer** is the named object
designated to carry out a state-changing call. A **resource** declaration names
data outside the workflow. A **proposition** is a named hypothesis,
assumption, or conclusion; nesting records their relationships. Information,
environment, and factors have distinct meanings.

A written method does not establish that its activities occurred or its
conditions were satisfied. Structural checks do not establish scientific
adequacy. Keep these boundaries explicit in examples and explanations.
Update the specification, manual, examples, and tests together when a
language rule changes.
