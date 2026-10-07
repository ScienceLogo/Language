# ScienceLogo design examples

The [first runnable slice](first-slice.rkt) is a small `#lang sciencelogo` program for
checking `to`, `do`, forward references, ordered blocks, and Logo's `print` command.
It prints a method reminder; it does not record scientific evidence. The supported
syntax is listed in the [first-slice contract](../spec/first-slice.md).
The [inputs and results example](inputs-and-results.rkt) shows a procedure receiving
one item and returning a named result.

The other examples are **provisional language sketches**, not executable ScienceLogo programs.
Their words and bracketed structure are candidates to test with scientists and learners.
They should inform the reader, validator, and run-record design before syntax is fixed.
The [draft semantic core](../spec/core.md) gives two of these sketches concrete run traces
and expected check outcomes.

Read each example in two ways: commands such as `measure`, `llm`, and `ask human` describe
activities; `must` states an obligation on the investigation or a named activity. A future
implementation needs to say exactly which obligations can be checked from the written
workflow, which need evidence from a run, and which need human judgment.
The [prompt and obligation design](../spec/prompts-and-obligations.md) proposes that `must`
be a checkable declaration, alongside named method components such as `prompt` and `agent`.
The [LLM variation design](../spec/llm-variation.md) expands the synthesis example with
multiple recorded suggestions and a stated review policy.

Each activity also needs a scientific context. `measure height` must eventually identify a
plant, date, and unit; screening changes a paper's status; fitting creates a model tied to
particular data. The first sketch leaves some details open for a beginner, while later
sketches test how the language makes context explicit before an AI activity uses it.

The synthesis example also sketches a named agent's working environment: its given material,
model, prompt, available tools, memory, and stopping rule. The run must retain what the agent
actually received and did. The modelling example uses a simpler LLM activity with explicit
context. This tests whether one language can describe both forms of AI use.

| Example | Main design question |
| --- | --- |
| [Plant growth](plant-growth.md) | Can a beginner read the method and its evidence rule, then grow into more advanced science in the same language? |
| [Plant-growth standard](plant-growth-standard.md) | Can one reusable standard scaffold a method, validate its stages, check a run, and give prioritized advice? |
| [Knowledge synthesis](knowledge-synthesis.md) | Can LLM-assisted screening and extraction remain traceable to sources and human decisions? |
| [Rainfall modelling](rainfall-modelling.md) | Can the same concepts cover data preparation, model comparison, LLM proposals, and held-out evaluation? |

The plant example starts without an LLM. Its later extension gives an LLM a limited role in
describing photographs while preserving the original observations. This progression matters:
ScienceLogo is a language for scientific workflows in the AI era, including investigations
that do not use AI.
