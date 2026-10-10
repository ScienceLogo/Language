# ScienceLogo describes its assessor

The [interface](requirements/assessor.rkt) names five required parts of the
ScienceLogo assessor and declares which later parts depend on earlier ones. The
[complete method](method.rkt) names an implementation reference for every part.
The [incomplete method](missing-impact.rkt) omits `trace-impacts`; the assessor
reports that omission and its effect on `report`.

From an installed checkout, run:

```text
racket -l sciencelogo/assessor -- examples/meta-assessor/method.rkt
racket -l sciencelogo/assessor -- examples/meta-assessor/missing-impact.rkt
```

The second command exits with a nonzero status because it finds structural issues.
These files are also a template: copy the interface and method into another
project, rename the parts, describe their dependencies with `affects`, and replace
the implementation references. The interface file stays separate from the method
that claims to implement it.

The five part names belong to this assessor interface. They are not built-in ScienceLogo
workflow types, and a workflow does not have to name every activity or item. The
[abstract workflow model](../../spec/core.md#workflow-as-the-abstract-core) describes
the broader types and relationships being developed.

This first assessor checks **declarations and impact links**. A `provide` line is
an implementation claim, not proof that the referenced code performs the named
work. The assessor does not execute the scientific activities or inspect the
contents of implementation references. Further analyses can use the same parsed
method and interface structure.
