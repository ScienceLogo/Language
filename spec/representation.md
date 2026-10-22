# Shared representation of a written workflow

This contract defines the method information readers must preserve. The
Racket reader produces an inspectable workflow model, including paired-stage
state, call locations, declared performers, named data sources and storage,
and propositions with their updates. It also preserves optional `about`
descriptions of workflows, stages, and procedures.
The reference API exposes Racket values, not a language-neutral export
format. This contract defines information and relationships, not a
serialization format.
This contract covers a **written method**. A record of what happened and an
assessment of that record are separate things.

## Purpose

A reader's representation lets applications inspect ScienceLogo source.
Readers written in other languages must preserve the same meaning,
including control flow and references. A list of words or a flat list of
stages is insufficient. A program may use the representation to explain a
method or check a declared condition.

The representation makes no claim that a described action occurred. It does not
contain a scientific assessment simply because the source declares a `must` rule
or an interface implementation.

For example, consider this short method:

```text
#lang sciencelogo
workflow "Review a timing plan"
stage Prepare
do make-plan as plan
to make-plan [output "Time ten swings as the swing gets smaller."]
stage Review
print plan
```

The reader identifies two stage labels, one procedure definition, one call of
that procedure, the result named `plan`, and a later command that uses `plan`.
It retains the call before the later use even though the procedure definition
appears after the call in the source. It does not report that anyone timed a
pendulum.

## Information to preserve

- **Identity and origin.** Identify the language version, the source workflow
  and its revision, each included file, and each resolved library revision.
  Identify the source location of each declaration and command. Element
  identifiers must be unambiguous within the identified method revision;
  this contract does not standardize their spelling across implementations
  or their stability across revisions.
- **Definitions and structure.** Preserve the workflow title, procedure
  definitions and inputs, stage headers and paired-stage entry and exit state,
  performer declarations and named data sources and storage, record interfaces,
  named hypothesis, assumption, and conclusion declarations and nested children,
  imports, and includes. A stage remains a label and
  checkpoint, not a procedure call or variable scope. A procedure definition
  does not count as a call.
  Declarations and references use unquoted identifiers in source, including
  stages, interfaces, and libraries. Quotes identify string values. Resolve
  stage references from declarations, with no inference from capitalization.
  A name that could refer both to a stage and to another visible value or
  definition must be reported as ambiguous. The Racket model stores
  stage, interface, and library names as strings in their named fields; this
  storage choice does not make a quoted string a source-language identifier.
- **Human explanation.** Preserve each optional `about` description as Markdown
  text after ordinary string decoding, with its owning workflow, stage, or
  procedure and its own source location. Keep absent and empty descriptions
  distinct. Preserve attachment and text through includes and imports without
  interpreting prose as commands, dependencies, or established facts. Comments
  are discarded and do not substitute for these descriptions. See
  [descriptions](descriptions.md).
- **Commands and values.** Preserve each command, its arguments and result
  name where present, nested blocks, branches, loops, and the expressions
  needed to understand them. Lists, records, ranges, quoted text, and the
  explicit value `unknown` retain their distinct forms. An absent field is
  different from a field whose value is `unknown`. Preserve every explicit
  parenthesis group as `(group expression)`, including redundant and nested
  groups, with its source location in the reader's tree. The interpreter and
  structural checks evaluate its enclosed expression. They must not remove
  groups from the recorded method. Preserve a value's attached
  `u` description, including its named `declared` and `omitted` sources and
  open fields, separately from the underlying value.
- **References and relationships.** Preserve the resolved target of each
  procedure call, performer reference, imported name, variable read, assignment,
  data read or write, and interface
  reference. Preserve nested proposition relationships and updates without
  inferring that a conclusion is sound. Preserve each direct `implement`
  mapping: whether its subject is a stage, procedure, or value; its resolved
  subject reference and declaration scope; the target interface's identity,
  version, source revision, and nested requirement path. Keep multiple mappings
  to or from the same part. For a
  paired-stage call, preserve each named input location and
  its return location and effective performer, whether named on the call or
  inherited from its stage. Keep each location's source expression alongside
  its resolved path, so parentheses in list positions remain inspectable.
  In the Racket reader, `(location resolved-path source-expression)` retains
  both. A state call retains a final `(locations input-locations return-location)`
  entry; the workflow activity's details retain this after the input paths,
  return path, and effective performer. Preserve containment, required order, result production and use,
  and the dependencies that follow from them. The representation must not
  invent an order between activities that the method leaves unordered.
- **Conditions.** Preserve each declared requirement or guard, its target,
  scope, and the point at which it is relevant. The representation records
  what is required, without recording it as satisfied. An assessor's finding
  belongs to a separate assessment record.
  For conditional interface entries, preserve the governing expression and
  the surrounding named part whose entries it references. Preserve the
  branch order: a later `else if` or `else` requires earlier conditions to
  be false. Effective guards may express this explicitly with `not` and
  `and`, while retaining each entry's source location and parent scope.
  Preserve value requirements inside `must [...]` separately from field
  defaults and presence requirements, including all referenced entry paths.
  Equality comparisons use `==`; assignment and default expressions retain
  their distinct `=` meaning.
  Membership and field presence use `(compare in (left right))`. Preserve
  both operands. With a record on the right, a bare left name is a field
  label; with a list, it refers to a value. Any inferred value dependency
  or required entry for that name is conditional on a list receiver.
  A required data field rejects `unknown` unless its resolved declaration
  supplies a default of `unknown`. Preserve that default as both the missing
  value to insert during construction and the field's explicit permission.
  Keep an explicitly supplied unknown distinct from a value the checker
  cannot resolve from the method. Permission for a field does not waive
  conditions on its value or requirements on its children.
  Equality and inequality compare explicit unknown markers normally,
  including markers nested inside records and lists. Retain the distinction
  between an explicit marker and unavailable information when checking those
  expressions; unavailable information does not become an asserted unknown.
  Concrete defaults also constrain the field's outer value kind. Preserve
  the default expression from which that kind is determined. An explicitly
  qualified unknown default is retained as, for example,
  `(typed-default number ((literal unknown)))`; its unknown permission and
  numeric kind apply together. A separate kind test is
  `(kind-test number ((result period)))`. Kind labels are not variable
  references. Preserve these forms through inheritance, imports, and nested
  requirements, with their source locations.
  A named-interface unknown default uses the same form, for example
  `(typed-default timing-tools.Timing ((literal unknown)))`. Preserve its
  compulsory presence, default, explicit unknown permission, and resolved
  interface reference as one field declaration. The suffix does not create
  another required field. An existing object is checked without inserting
  child defaults; an unavailable value stays distinct from explicit unknown.
  A named interface test retains its resolved reference, as in
  `(kind-test timing-tools.Timing ((result timing)))`. The Racket
  `interface-model` also retains `declarations`: the interface definitions
  available at that point, including resolved library definitions. They
  give a checker the same definition context without fetching a different
  library revision. Include these definitions in the interface model's
  revision identity. Matching is a check; it does not construct an object
  or insert defaults.
  An optional field constraint is separate from its presence and default:
  `(interface-field notes #f #f #f (kind-test text ((result notes))))`.
  The model retains an `optional-entry` and a `field-constraint` scoped to
  it. Skip this constraint when the field is absent. Its references do not
  create compulsory entries; supplied unknown values can leave the check
  undetermined. Preserve its source location and enclosing conditional
  guard through nested groups, list-item declarations, and inheritance.
  Preserve `.count` references in expressions. On a list, this is a read-only
  computed property, not a separately supplied field or protocol part.
  A count requirement identifies the list it reads and retains the full
  comparison for inspection. Unknown item values do not obscure the count
  of a list whose positions are known.
  For `for each` inside an interface, preserve its collection expression,
  local item name, enclosing scope, guard, and the body with its nested
  requirements and source locations. The body describes each item; it is
  not an executed workflow activity or a set of enclosing workflow names.

Inputs, results, and other values appear through the commands and references
that use them. ScienceLogo does not impose a generic `Item` type or a catalogue
of scientific objects. Libraries can define records and interfaces for their
own domains.

## Checks on a reader

Two conforming readers must agree on the parts and relationships that valid
source states, even if their internal data structures differ. At minimum, a
reader must reject unresolved or ambiguous names, invalid scope use, and
malformed syntax according to the language specification. It must preserve a
branch or loop as such instead of reporting every command inside it as an
unconditional action. A source map must let a tool point back to the text that
gave rise to a represented part or relationship.

The [language rules and reference behavior](first-slice.md) define the source
rules and structural checks. The [examples](../examples/README.md) illustrate
them. Readers can be compared by the method information they preserve,
without requiring the same internal data structures or an export format.
