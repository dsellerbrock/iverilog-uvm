# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M11 milestone-COMPLETE head 3d70294 (212/212,
4x53 batches, 2026-07-24 — covered M11-3/4/5/6: with-function sample,
package stub-class removal, auto-bin sizing/enum bins, ignore/illegal
carving, registry dedupe, and class-embedded event sampling with the
new %covgrp/sample/all runtime).

Commits since full UVM: 3 (ivl.def Windows export list; M9-11 expect
statement; M9-7 D.2 multiclock chain pipelines — both pform-only
lowerings, covered by sva_nfa 36/36, negative 53/53, UVM sva 19/19,
smoke 14/14, full ivtest fail-list byte-identical at each)
Highest risk change since last full run: LOW-MEDIUM (M9-11/M9-7
touch only SVA lowering paths in pform.cc)

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
