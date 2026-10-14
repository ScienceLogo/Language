# Context sets in a scientific method

**Status:** meaning and design rationale for the three sets. The adopted
[paired-stage syntax and constraints](stage-state.md) are documented separately;
the [manual page](../scribblings/stages.scrbl) teaches their use. This page
does not define how an assessment application analyzes the sets.

## What context covers

Context is the information and circumstances relevant to a particular piece of
scientific work. A workflow should state the context it considers relevant; it
cannot list everything in the world that might matter. Different activities in
the same workflow may have different contexts. A source available to a scientist
is not automatically available to an AI agent.

ScienceLogo distinguishes three named sets within a stage's state:

| Set | Question it answers | Examples |
| --- | --- | --- |
| **Information set** | What information, instructions, or source material is designated as available to this activity or actor? | Research criteria, data, a paper's abstract, a prompt, a supplied passage, or the contents of retained memory. |
| **Environment set** | Under what relevant physical or digital conditions is the activity specified to take place? | A stopwatch and pendulum setup, instrument settings, software or model version, available tools, or a retrieval setup. |
| **Factors set** | Which possible influences has the scientist considered when interpreting an activity or result? | Human reaction time in hand timing, release angle, text order or truncation in an LLM request, or a model change between attempts. |

An information set names material made available at a particular point. It does
not claim that the actor read or used every member. An environment set names the
relevant setup; it does not claim that an intended setting was in effect during an
observed run. The written method and a record of what actually happened remain
distinct.

Hypotheses can be kept as a named collection within the information set. Each
claim can retain its identity, status, and links to the observations used to
assess it. A later claim can refer to an earlier one without erasing it. This
does not make hypotheses a fourth set required by every workflow.

The factors set is a set of **considered** influences, not a list of factors the
scientist has necessarily controlled. A factor can refer to something already
named in the information or environment set. For example, release angle can be
part of the pendulum environment and also a considered factor for the measured
period. When useful, the workflow can say which activity or result a factor may
affect and how the method handles it. Merely naming a factor does not establish
that its influence is negligible or that a control worked. **Controls** are the
factors for which the method states a means of control or accounting; the word
does not name the entire third set.

Whether something is a nuisance factor depends on the research question. Model
version may be a possible unwanted influence in a paper-screening study and the
main subject of a study comparing models. The language must not impose a fixed
catalogue of nuisance factors on all workflows. An undeclared factor cannot be
treated as negligible merely because it is absent; whether an expected factor is
missing is a separate scientific question.

## Two examples

For a pendulum timing activity, the information set might name the question,
the initial hypothesis about shrinking swings, timing instructions, and the
definition of a full swing. The environment set might name the pendulum,
stopwatch, and release setup. The factors set might identify human reaction
time and changes in swing angle during timing as possible influences on the
recorded period. The method can describe how it handles each without asserting
that the timing has already happened. The [young Galileo example](../examples/pendulum-period.md)
follows the hypothesis, observations, and revised explanation across stages.

For an AI-assisted paper-screening activity, the agent's information set might
contain the inclusion criterion, title, abstract, and prompt. The full text may
belong to a human reviewer's information set without belonging to the agent's.
The agent's environment set might name the model version, settings, available
tools, and memory setup. The factors set might identify text order, truncated
context, or earlier conversation as possible influences on a suggestion. These
are considered relative to that screening activity; another investigation may
give them different roles.

## What the language needs to preserve

The three labels distinguish named collections of ordinary values, records, and
references; they do not impose fixed scientific fields. Each set needs an
unambiguous identity and scope. Its members must be referable without copying
their descriptions into every activity. A set's location or an explicit
reference shows which activity it describes. Additional links, such as a factor
to a particular result, can be stated when the workflow needs them. These are
descriptions of the **specified method**. A later record of a particular run
may state what information was actually supplied and what environment was
actually in effect, without turning the method's declarations into claims that
those events occurred.

## How the sets appear in the language

The adopted [paired-stage form](stage-state.md) names the incoming and
outgoing sets and gives each procedure input and return a location in them.
The reader checks names, locations, and declared flow. It does not execute
the paired stage's body, establish that work happened, or judge whether a
returned value is scientifically suitable. A record of an observed run would
need its own values and evidence. Applications using ScienceLogo decide how
to assess the sets for a particular scientific purpose.
