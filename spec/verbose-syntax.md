# ScienceLogo verbose syntax

**Status:** agreed language specification. Verbose parsing and source translation
are awaiting implementation. The current reference reader accepts compact
syntax. The examples of verbose and mixed syntax below define their intended
spelling; they are not runnable with that reader yet.

## Purpose and scope

ScienceLogo has two equivalent ways to write the same language. Compact syntax
is the reference form for language checks. Verbose syntax spells selected
operations in words. A source file may mix the two.

The [compact grammar](compact.ebnf), its
[context and binding rules](../scribblings/grammar.scrbl), and the contracts
linked from the [documentation map](README.md) continue to define meaning.
Each verbose form below has the same scopes, values, requirements, placement
rules, and checks as its compact equivalent. Scientific assessment remains the
responsibility of applications using the language.

The tables use example names and values as patterns. Replace those names and
values as appropriate. Brackets and parentheses shown as source punctuation
retain their existing meaning. Both forms use `#lang sciencelogo`.

## 1. Values, fields, and updates

### Assignment and fields

| Compact | Verbose |
| --- | --- |
| `period = 2` | `set period to 2` |
| `trial.period = 2` | `set period of trial to 2` |
| `trials.[2] = value` | `set [2] of trials to value` |
| `trial = [period = 2 unit = "seconds"]` | `set trial to [set period to 2 set unit to "seconds"]` |

`set … to …` creates or updates a name according to the same scope and update
rules as `=`. Inside object brackets, it supplies a field of that object.
Inside an interface, it supplies a default. The surrounding grammar determines
which of these roles applies.

The field rule applies at every nesting depth:

```text
; Compact
trial = [clock = [unit = "seconds"]]

; Verbose
set trial to [
  set clock to [
    set unit to "seconds"
  ]
]
```

### Reading nested content

| Compact | Verbose |
| --- | --- |
| `trial.period` | `period of trial` |
| `experiment.trial.period` | `period of experiment.trial` |
| `trials.[2]` | `[2] of trials` |
| `trials.[1 3]` | `[1 3] of trials` |
| `experiment.trial.[period unit]` | `[period unit] of experiment.trial` |
| `grid.[1].[2]` | `[2] of grid.[1]` |

Only the final access is expressed with `of`. The containing path stays dotted,
however many levels it has. Do not translate `experiment.trial.period` into a
chain such as `period of trial of experiment`.

This rule also applies to assignment targets and stage input and output
locations. Procedure inputs keep their colon: `:trial.period` becomes
`period of :trial` inside that procedure.

The existing properties retain their names: `trials.count` can be written
`count of trials`, and `period.u` can be written `u of period`. The attachment
word `uncertainty` introduced below does not rename the `u` property.

Library-qualified procedure and interface names retain their qualified spelling,
such as `methods.estimate-period` and `methods.Timing`. Resolve them from their
declarations as required by the compact language.

### The `+=` operation

| Compact | Verbose |
| --- | --- |
| `target += value` | `update target with value` |
| `trial.period += 2` | `update period of trial with 2` |

These are exact equivalents. The value already held by the target determines
the operation in both forms:

| Existing target | Effect of `+=` and `update … with …` |
| --- | --- |
| Number | Add the numeric value. |
| List | Append the entire supplied value as one item. |
| Record | Merge supplied named fields, adding missing fields and updating existing ones according to the compact record rules. |
| Proposition or proposition collection | Add a named proposition under the applicable collection; existing duplicate and type rules apply. |

The translation is the same for all targets; it does not need to infer their
types. Existing restrictions also remain, including the requirement for an
explicit replacement and uncertainty description when changing a value carrying
`u`.

For a list, replacing an entry uses `=` on that position. Appending uses `+=` on
the list itself:

```text
; Compact
values = [1 2]
values.[2] = 3         ; values is now [1 3]
values += 4            ; values is now [1 3 4]
values += [5 6]        ; values is now [1 3 4 [5 6]]
```

```text
; Verbose
set values to [1 2]
set [2] of values to 3
update values with 4
update values with [5 6]
```

### A value with selected fields or positions changed

| Compact expression | Verbose expression |
| --- | --- |
| `trial.[period = 2]` | `trial with [set period to 2]` |
| `Timing.[duration = 20]` | `Timing with [set duration to 20]` |
| `values.[2 = 3]` | `values with [set 2 to 3]` |

These expressions produce a value. An existing record or list supplies the
starting value; an interface supplies its defaults and construction requirements.
The existing field, nesting, and position rules apply. Numeric keys inside a
list-position update describe positions.

Assigning the expression to another name retains the original value:

```text
revised = trial.[period = 2]
set revised to trial with [set period to 2]
```

The two lines above are alternative spellings of the same assignment.

A standalone compact command that updates several fields or positions uses
assignment back to the same target in verbose syntax:

```text
; Compact
trial.[unit = "minutes" duration = 3]

; Verbose
set trial to trial with [
  set unit to "minutes"
  set duration to 3
]
```

The same rule covers list-position replacements. It keeps them distinct from
the append operation represented by `update … with …` on a list.

## 2. Expressions and conditions

### Comparisons and logic

| Compact | Verbose |
| --- | --- |
| `a == b` | `a equals b` |
| `a != b` | `a does not equal b` |
| `a < b` | `a is less than b` |
| `a <= b` | `a is at most b` |
| `a > b` | `a is greater than b` |
| `a >= b` | `a is at least b` |
| `a xor b` | `a exclusive or b` |

`and`, `or`, and `not` are shared, including expressions such as
`ready and not excluded`. Arithmetic `+`, `-`, `*`, and `/` is shared.

Each operator has the binding strength, associativity, and meaning of its
compact equivalent. The words within `does not equal` form one comparison;
`exclusive or` is the equivalent of `xor`. Parentheses retain their existing
role and every explicit group is preserved.

### Membership, field presence, and type checks

| Role | Compact | Verbose |
| --- | --- | --- |
| List membership | `"manual" in methods` | `is "manual" in methods` |
| Field presence | `notes in trial` | `is notes in trial` |
| Value-kind check | `period is number` | `is period a number` |
| Interface check | `trial is Timing` | `is trial a Timing` |

The list membership and field-presence forms share the existing `in` rules.
For an object, the left name identifies a field. For a list, the left
expression supplies the value being searched for.

The `is … in …` and `is … a …` forms are questions that produce the same
Boolean or unknown result as their compact equivalents. They can occur
where those compact conditions can occur, including in interface requirements.
They keep the comparison-level binding of those conditions when combined with
`and`, `xor`, and `or`. Grouping remains available:

```text
if (is notes in trial) then [
  print trial.notes
]
```

### Numeric ranges

```text
; Compact
lengths = range 0.25 to 1 step 0.25

; Verbose
set lengths to range from 0.25 to 1 with step 0.25
```

Both produce the same reusable range value. Bounds, direction, endpoint,
and step checks remain unchanged.

## 3. Procedures and control flow

Procedure definitions, inputs, calls, result naming, and returns keep
`to`, `:input`, `do`, `as`, and `output`:

```text
to estimate-period :duration :swings [
  output :duration / :swings
]
do estimate-period 20 10 as period
```

`print value` and `do [ … ]` are also shared. Statements and expressions
inside any command block may use either spelling.

| Compact | Verbose |
| --- | --- |
| `repeat 3 [ … ]` | `repeat 3 times [ … ]` |
| `if condition [ … ]` | `if condition then [ … ]` |
| `else if condition [ … ]` | `else if condition then [ … ]` |
| `else [ … ]` | `else [ … ]` |

The other loop structures stay shared:

```text
for each value in values [ … ]
while condition [ … ]
repeat [ … ] until condition
```

Conditional and per-item interface bodies follow the same spelling rules as
the corresponding control structures. Their contents remain interface entries.

## 4. Stages and state locations

| Compact | Verbose |
| --- | --- |
| `stage measure` | `start stage measure` |
| `stage measure by observer from state [ … ]` | `start stage measure by observer from state [ … ]` |
| `end stage with state [ … ]` | `end stage with state [ … ]` |

The closing command is identical. A simple stage header still labels a section;
its verbose spelling preserves the same boundaries. A paired stage retains its
required entry and exit state objects, including when they are empty.

`state`, `information`, `environment`, and `factors` retain their names.
Assignments within state objects follow the recursive field rule, such as
`information = [elapsed = unknown]` becoming
`set information to [set elapsed to unknown]`. Existing rules determine which
sets and values are supplied; the verbose syntax adds no fields or handoff
requirements.

Location-based calls keep `do`, `by`, `with`, `at`, and `into`:

```text
; Compact
do estimate-period with [
  duration at information.elapsed
  swings at information.swing-count
] into information.period

; Verbose
do estimate-period with [
  duration at elapsed of information
  swings at swing-count of information
] into period of information
```

The input names are unchanged. The locations use the final-access rule.
The stage's performer and any call-level override keep their existing meaning.
These spelling changes preserve all restrictions on state-changing calls and
local control names in paired stages.

## 5. Declarations and requirements

### Interfaces and defaults

`interface`, `version`, `extends`, and `must` are shared. Extension and
combination retain their existing rules. Defaults use the field assignment
equivalence:

```text
; Compact
interface Timing [
  version "1"
  must [duration unit = "seconds"]
  notes
]

; Verbose
interface Timing [
  version "1"
  must [
    duration
    set unit to "seconds"
  ]
  notes
]
```

Both require `duration` and `unit`, supply the default `"seconds"` for `unit`,
and leave `notes` optional. A default retains its existing requiredness,
inferred kind, and overridability wherever it is written.

A field's type declaration within an interface has its own statement form:

| Compact declaration | Verbose declaration |
| --- | --- |
| `duration is number` | `duration is a number` |
| `timing is Timing` | `timing is a Timing` |
| `duration = unknown number` | `set duration to unknown number` |

A type declaration states a field constraint. The question
`is duration a number` checks a value. A typed unknown default explicitly
permits `unknown` and preserves the type required of a known value.
`unknown` and type labels retain their existing spellings.

### Implementation mappings and declared connections

| Compact | Verbose |
| --- | --- |
| `measure implement Protocol.measurement` | `measure implements Protocol.measurement` |
| `affects measurement analysis` | `measurement affects analysis` |
| `must do estimate-period` | `must do estimate-period` |
| `must stages in order [prepare measure report]` | `must do stages in order [prepare measure report]` |

An implementation mapping retains its target, including any nested interface
part. Stage and procedure names remain unquoted. An `affects` declaration
retains its direction and its placement inside an interface.

The full phrase `must do stages in order [ … ]` is the verbose stage-order
requirement. `must do name` continues to require a procedure call.
Requirements written inside `must [ … ]` may use either spelling of their
comparisons and other expressions.

### Performers, resources, and propositions

The declaration words `performer`, `resource`, `hypothesis`, `assumption`,
and `conclusion` are shared. Their fields use the recursive assignment rule:

```text
; Compact
performer observer [name = "Observer"]
resource timings [url = "https://example.org/timings.csv"]
hypothesis shorter-swing [text = "A shorter swing has a shorter period"]

; Verbose
performer observer [set name to "Observer"]
resource timings [set url to "https://example.org/timings.csv"]
hypothesis shorter-swing [
  set text to "A shorter swing has a shorter period"
]
```

The `hypotheses`, `assumptions`, and `conclusions` collection names are shared
at every nesting depth. A nested addition uses the ordinary `+=` equivalence:

```text
update hypotheses.shorter-swing with conclusion not-supported [
  set text to "The measurements did not support a shorter period"
]
```

All proposition relationship, naming, and duplicate rules remain unchanged.
An independent conclusion keeps the same root declaration form.

Resource data access uses the existing assignment and field-access rules:

| Compact | Verbose |
| --- | --- |
| `elapsed = timings.elapsed` | `set elapsed to elapsed of timings` |
| `timings.period = elapsed` | `set period of timings to elapsed` |

Both preserve the direction of the stated data flow. The requirement to
reference external data through declared resources applies equally in both
syntaxes. Source-code dependency paths keep their separate rules.

### Uncertainty attachment

| Compact | Verbose |
| --- | --- |
| `value u [ … ]` | `value with uncertainty [ … ]` |

For example:

```text
; Compact
period = 2 u [declared = [timing = [estimate = 0.1]]]

; Verbose
set period to 2 with uncertainty [
  set declared to [
    set timing to [
      set estimate to 0.1
    ]
  ]
]
```

`declared` and `omitted` keep their existing meaning and shape. Source names,
classification fields, and other user-supplied fields are unchanged.
The attachment applies to the same preceding value expression; parentheses
continue to group a whole calculation when needed.

## 6. Libraries, files, and descriptions

| Compact | Verbose |
| --- | --- |
| `import "file:///path/to/hello-world" at "v1.0.0" as hello` | `import library from "file:///path/to/hello-world" at "v1.0.0" as hello` |
| `include "methods/timing.rkt"` | `include "methods/timing.rkt"` |
| `library hello-world [ … ]` | `library hello-world [ … ]` |
| `workflow "Pendulum experiment"` | `workflow "Pendulum experiment"` |
| `about "Compare pendulum periods at different swing sizes."` | `about "Compare pendulum periods at different swing sizes."` |

Library layout, alias visibility, version selection, transitive imports,
and relative include paths follow the existing library contract. Importing
a library preserves the separate identities of its versioned interfaces.

Workflow titles remain optional text. The `about` form remains optional
Markdown in its existing workflow, stage, and procedure attachment positions.
Neither form quotes an identifier.

The existing file-reference form is also shared:

```text
implements "protocol.rkt" as protocol [
  provide measurement by "Manual timing of ten swings"
]
```

A declaration beginning with `implements` has this existing file-reference role.
A verbose mapping such as `measure implements Protocol.measurement` has its
subject first. The quoted text after `by` in the file-reference form is text.

## 7. Shared notation and mixed source

Numbers, quoted strings, `true`, `false`, `unknown`, list brackets,
object brackets, and parentheses keep their existing rules. Names are
case-sensitive unquoted identifiers. Capitalization and hyphen conventions
remain optional.

Comments use the same forms in both syntaxes:

```text
; Explain the next step.
#|
Explain a longer part of the workflow
across several lines.
|#
```

Compact and verbose forms may mix within a file, a block, an object, or an
expression. For example:

```text
set trial to [duration = 20 set swings to 10]
period = trial.duration / swings of trial
if period >= 2 and not (is notes in trial) then [
  print period
]
```

The mixed example has the same compact meaning as:

```text
trial = [duration = 20 swings = 10]
period = trial.duration / trial.swings
if period >= 2 and not (notes in trial) [
  print period
]
```

Recognize complete grammatical forms in their surrounding context. A `set`
inside an object supplies a field; the same word at command position begins
an assignment. A type declaration inside an interface and a question about a
value have distinct forms. A copied value introduced by `base with [ … ]`,
an uncertainty attachment introduced by `with uncertainty`, and a stage call's
`with [input at location]` retain their separate roles.

Use the compact binding and placement rules after applying the equivalences.
All parts of a compact construct not given a different spelling here stay
shared, including the contents of ordinary names and type labels.

## 8. Translation and preservation

A translator must accept compact, verbose, and mixed source and be able to
produce either compact or verbose source. All variants use the same language
checks through their compact equivalents.

Translation must preserve:

- Names, their spelling and case, bindings, references, and input colons.
- Values, the contents of strings, and the text and Markdown inside `about`.
- Every explicit parenthesis group, including redundant and nested groups.
- Comment text and its placement relative to the surrounding code.
- Command order, nesting, stage boundaries, and declared relationships.
- The original locations of source constructs for diagnostics and inspection.

Translate grammatical constructs rather than substituting matching words
throughout a file. Text such as `"set period to 2"` stays exactly that string.
The translator must retain comments and groups as source information.
The current compact reader discards comments, so its existing tree alone is
insufficient for this preservation requirement.

A compact-to-verbose-to-compact round trip must retain the same workflow
meaning and the preserved information above. The standalone field-update
command may return in its equivalent assignment-back form. Spacing and
indentation can change while preserving comments and explicit groups.
The translator may add parentheses where needed to preserve expression
binding, while retaining every group already written by the author.

Both forms preserve the language's boundaries: paired stages describe work;
resource access describes external data flow; an implementation mapping
records a stated relationship. Their verbose spelling introduces no scientific
execution, conformance verdict, or uncertainty calculation.

## 9. Checks for a future implementation

The implementation work must cover these cases with the same compact behavior:

1. Assignments and nested object fields, including identical field and outer
   variable names.
2. Numeric addition, list appending, record merging, and proposition additions
   through `+=` and `update … with …`.
3. List-position replacement, multi-position updates, and modified values
   assigned to new or existing names.
4. Final-only `of` access for fields, selections, procedure inputs, state
   locations, and properties; qualified procedure and interface names stay intact.
5. Every comparison, logical operator, question form, and explicit grouping,
   including their binding in mixed expressions.
6. Procedure calls, ranges, all loop forms, and every conditional branch.
7. Interface declarations, defaults, unknown permissions, nested parts,
   inheritance, conditions, and per-item requirements.
8. Stage entry and exit state, performers, location-based calls, and resource
   assignments under the existing constraints.
9. Implementation mappings, `affects` direction, required calls, stage order,
   and the existing file-reference form.
10. Comments, strings, descriptions, names, and nested parentheses across both
    translation directions and mixed input.

These are language-equivalence cases. The scientific judgments of independent
assessment applications remain outside this syntax specification.
