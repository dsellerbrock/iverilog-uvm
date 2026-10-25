# #759 T1 selection

- Implementation commit: `f4f31e6ea` (class-handle RHS validation in shared `elaborate_rval_expr`).
- Candidate T1 before the main refresh: `062083fc7`; the `PENull` guard was subsequently committed as `6a3fde2` and the branch merged current `origin/main` `bffb163dc` at `30d7f92fa`.
- The final follow-up updates the source-type check to use the cached `PExpr::expr_type()` on identifier sources and corrects two 2023 wrapper include paths. Its committed SHA is recorded at the start of `t1-candidate.log`.
- Graph basis: `elaborate_rval_expr` serves direct assignments, compressed/compound assignment paths, and output clockvar drives; the guard distinguishes integral destinations from class-typed sources.
- Selection covers class/object, chandle/null/cast/process/randomize, virtual-interface/modport, enum casts, struct/array writes, port/formal/ref binding, compound/nonblocking assignment, clocking drives, and procedural continuous assignment tests.
- Current selection has 1,481 legacy rows (1,481 unique keys) and 1,399 JSON rows (1,399 unique keys), including paired #759 initializer/property, specialization, and generic-`new` tests. It preserves the graph-selected categories and adds all rows newly introduced to the manifests between `e909bcbfc` and `bffb163dc`, so the refreshed run covers current-main additions. Run with `.github/ivtest_focus_gate.sh`.
- The previous job `4859` tested the pre-refresh snapshot: 1,460/1,460 legacy and 1,371/1,371 JSON passed, but it is not final current-base evidence; UVM checks stopped because the Slurm snapshot omitted the submodule.
- The e909 baseline is expected to reject/fail the six new #759 compile-error regressions and may not contain later-main behavior. Compare its failure set only for tests it supports; all candidate tests must pass.
- T1 also includes the UVM runtime gate and smoke set on the candidate. Full legacy and JSON suites remain a T2 batch requirement per `CI-PIPELINE.md`.
