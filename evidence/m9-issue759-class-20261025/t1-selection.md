# #759 T1 selection

- Implementation commit: `f4f31e6ea` (class-handle RHS validation in shared `elaborate_rval_expr`).
- Candidate T1 snapshot: `062083fc7`; the later `50132a818` commit only corrected the §14.16.1 citation in docs, with no source or test changes.
- Graph basis: `elaborate_rval_expr` serves direct assignments, compressed/compound assignment paths, and output clockvar drives; the guard distinguishes integral destinations from class-typed sources.
- Selection covers class/object, chandle/null/cast/process/randomize, virtual-interface/modport, enum casts, struct/array writes, port/formal/ref binding, compound/nonblocking assignment, clocking drives, and procedural continuous assignment tests.
- Selection counts are 1,461 legacy rows (1,460 unique keys) and 1,372 JSON rows (1,371 unique keys). Both runners use the same category rules: names are selected independently from `regress-sv.list` and `regress-vvp.list`; full manifest rows (including type/options and JSON descriptors) are in `t1-legacy.list` and `t1-json.list`; repeated keys are preserved so each runner applies the same duplicate-resolution rules as the main manifest. Run serially with `.github/ivtest_focus_gate.sh`.
- Expected baseline-only failures: the six new #759 compile-error regressions, because unmodified main accepts class-handle-to-integral assignments. Exclude these six from failure-set comparison; all other baseline failures must match the candidate.
- T1 also includes the UVM runtime gate and smoke set on the candidate. Full legacy and JSON suites remain a T2 batch requirement per `CI-PIPELINE.md`.
