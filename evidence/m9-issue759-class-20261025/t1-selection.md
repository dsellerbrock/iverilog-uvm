# #759 T1 selection

- Commit under test: `f4f31e6ea` (class-handle RHS validation in shared `elaborate_rval_expr`).
- Graph basis: `elaborate_rval_expr` serves direct assignments, compressed/compound assignment paths, and output clockvar drives; the guard distinguishes integral destinations from class-typed sources.
- Selection covers class/object, chandle/null/cast/process/randomize, virtual-interface/modport, enum casts, struct/array writes, port/formal/ref binding, compound/nonblocking assignment, clocking drives, and procedural continuous assignment tests.
- Both runners use the same category rules: names are selected independently from `regress-sv.list` and `regress-vvp.list`; selected names are in `t1-legacy.list` and `t1-json.list`. Run serially with `.github/ivtest_focus_gate.sh`.
- Expected baseline-only failures: the six new #759 compile-error regressions, because unmodified main accepts class-handle-to-integral assignments. Exclude these six from failure-set comparison; all other baseline failures must match the candidate.
- T1 also includes the UVM runtime gate and smoke set on the candidate. Full legacy and JSON suites remain a T2 batch requirement per `CI-PIPELINE.md`.
