# Attached uncertainty descriptions

The reader checks the shape described here, and the interpreter retains and
reads the attached description.
Scientific uncertainty calculations and judgments belong to applications and
libraries, not to the language core.

## Form and meaning

```text
period = 2.01 u [
  declared = [
    timing-resolution = [type = "epistemic" estimate = 0.02 unit = "s"]
    trial-spread = [type = "aleatory" estimate = unknown]
  ]
  omitted = [
    reaction-delay = [reason = "not estimated"]
  ]
]
```

`u` attaches an uncertainty description to the value immediately before it.
It can follow any value expression; use parentheses to attach it to a whole
calculation, for example `(duration / swings) u [...]`. It is a reserved word.
`period` is still the numeric value `2.01`; `period.u` is the attached record.
The same rule works for values in records, procedure results, and stage state.

The `u` record has only two possible top-level fields:

- `declared`: named uncertainty sources considered in the description.
- `omitted`: named sources known to have been left out of the description.

Either collection can be absent or `[]`; the interpreter treats it as an empty
named record. Each source has a distinct name within its collection and a
record of fields, which may itself be empty. The fields inside a source are
open: `estimate`, `unit`, `reason`, `type`, and other names are ordinary fields,
not mandated vocabulary. A known source judged negligible belongs under
`declared` with that judgment written in its fields; `omitted` is for a source
left out. `estimate = unknown` records that a source was considered while its
magnitude is unknown.

For example, `period.u.declared.timing-resolution.estimate` reads `0.02`, and
`period.u.omitted.reaction-delay.reason` reads `"not estimated"`. Reading
`.u` on a value without an attached description is an error. `u []` attaches
an explicit empty description; it does **not** state zero uncertainty. A value
with no `u` has no uncertainty description.

## Classifications

`type` is an optional field inside a source. A workflow or library may use
`type = "aleatory"`, `type = "epistemic"`, or another label. It can use a list
when more than one classification applies:

```text
model-form = [type = ["aleatory" "epistemic"] reason = "Both sources apply"]
```

The reader preserves these labels but does not define their scientific
meaning, require either category, or decide whether a classification is
correct. A library can define a more specific record interface or assessment
rule for a field set.

## Copies, updates, and calculations

`copy = period` copies the value and its attached `u` record. Later changes to
one name do not change the other. Dotted paths can revise the description,
for example `period.u.declared.timing-resolution.estimate = 0.03`.
`period.u = [...]` replaces the whole description on an already qualified
value. Its top-level fields and source entries must retain the shape above.

`period = 2.02` replaces the whole value and removes its old `u`; use
`period = 2.02 u [...]` to attach a new description. `+=` on a qualified value
is rejected because preserving an old uncertainty description after changing
its value would be misleading. Arithmetic and comparisons use the underlying
value. Arithmetic results have no automatic uncertainty propagation: write a
new `u` description on the resulting expression if one is needed. In a
workflow, any scientific propagation method and its justification must be
supplied by the author or an external application.

The workflow model retains the `u` expression and its source location for
inspection. The reference interpreter runs ordinary value operations and reads
the description; it does not estimate uncertainty or assess whether the
listed sources are adequate.
