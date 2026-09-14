# L51 — Resolve package-qualified tasks consistently

An explicit call to a missing package task compiled and continued after a
warning. Inside a package, the parser can represent `pkg::task_name()` as a
two-component name without the explicit package pointer. That representation
also discarded a valid forward-declared task: `qualified_package_self_valid.sv`
leaves its counter zero in both editions. The missing and valid same-package
reducers are recorded in `package-self-results.json` and
`package-self-valid-results.json` under `evidence/unresolved-task-assessment`.

`missing_package_unit_shadow.sv` also demonstrates an incorrect upward
resolution: `existing_pkg::missing()` executes a compilation-unit task named
`missing`. Both editions print `WRONG_UNIT_TASK`; the durable result is
`package-unit-shadow-results.json`.

IEEE 1800-2017/2023 13.3, 23.7.1 and 26.3 require task lookup and execution
against the named package. In particular, 23.7.1 forbids upward lookup for a
`::` prefix. Valid package tasks and statement-form functions must retain
their effects; a missing explicitly named package subroutine must not become
a successful no-op, including when the caller has a same-named class method.

Task and function lookup now offer a downward search through the existing
scope/import resolver. Explicit package calls select that search; ordinary
callers retain their existing upward behavior. The same-package parser form
rebases the package prefix to the subroutine name. Missing qualified calls
bypass the warning/no-op fallbacks. Lazy forward declaration handling remains.

Focused legacy 4/4 and JSON 8/8 pass. Permanent positives cover forward and
self-qualified tasks, void/nonvoid statement functions, and exported tasks and
functions. Negatives cover missing package members with compilation-unit task
and function shadows, a class method shadow, and a same-package caller. Root
review rejected an interim declaration-owner filter because valid exports can
refer to declarations in another package; the final resolver preserves those
exports. This is the ninth focused increment. Broad hierarchical/class fallback
obligations and full qualification remain open.
