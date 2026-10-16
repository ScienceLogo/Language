# ScienceLogo documentation map

The [language manual](../scribblings/sciencelogo.scrbl) is the reading and
lookup path. Its pages progress from a small investigation to values,
procedures, stages, data sources and storage, interfaces, files, and structural
checks. The Syntax page maps each accepted form to its main explanation. The website keeps these as
one level of pages with headings within each page.

This directory holds language contracts and design work. Read the **status**
at the top of a document before using a form: an accepted reader form is not
necessarily an executable command, and a design sketch is not accepted syntax.

| Document | Role and current status |
| --- | --- |
| [First runnable slice](first-slice.md) | Accepted forms the Racket interpreter runs, plus the current structural checks. |
| [Libraries](libraries.md) | Accepted layout, import, and include rules. |
| [Paired stages and state locations](stage-state.md) | Accepted reader syntax; checked as a written method but not executed. |
| [Data sources and storage](resources.md) | Accepted declarations and directional data paths; no external I/O. |
| [Context sets](context.md) | Meaning and rationale for information, environment, and considered factors. |
| [Language boundary](architecture.md) | Separation of language rules, readers, interpreters, and independent applications; compact and future verbose syntax. |
| [Shared representation](representation.md) | Design contract for what readers should preserve; portable format remains open. |
| [Semantic core](core.md) | Wider semantic design and proposed run traces, beyond current accepted syntax. |
| [Design principles](design-principles.md) | Goals and learning tests, not syntax. |
| [Prompts and obligations](prompts-and-obligations.md) | Design of broader conditions and AI requests; its sketches are not accepted forms unless separately listed above. |
| [LLM variation](llm-variation.md) | Design for attempts, context, replication, and control; not accepted syntax. |
| [Workflow publication support](workflow-documentation.md) | Design of information external publication tools would need; not a booklet format or implemented generator. |

## How pages are maintained

For each accepted form, state its spelling, where it is allowed, what it
means, what the reader checks, and whether it runs. Use a small example before
the full constraints. Give the detailed rule one home and link to it from
other pages. The manual can teach that rule without copying the entire
contract. Keep scientific examples explicit about what is a written method,
what is an observed event, and what is an assessor finding.

Use familiar terms consistently: a **stage** is a checkpoint, a **procedure**
is a reusable definition, a **call** invokes one, **state** names what a
paired stage receives and leaves, and a **performer** is the named object
designated to carry out a state-changing call. A **resource** declaration names
data outside the workflow. The information, environment, and factors
sets have distinct meanings. A written condition does not establish that it
was satisfied. A structural check does not establish scientific adequacy.

Proposed syntax remains in design documents with an explicit status. When a
form becomes accepted, update its contract, manual page, examples, and tests
together. Applications such as protocol or bias assessment may use the
language, but their scientific algorithms do not become built-in language
features merely because the design discusses them.
