# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M11 milestone-COMPLETE head 3d70294 (212/212,
4x53 batches, 2026-07-24 — covered M11-3/4/5/6: with-function sample,
package stub-class removal, auto-bin sizing/enum bins, ignore/illegal
carving, registry dedupe, and class-embedded event sampling with the
new %covgrp/sample/all runtime).

Commits since full UVM: 4 (ivl.def Windows export list; M9-11 expect
statement; M9-7 D.2 multiclock chain pipelines; M12-4 assoc-element
VPI writes — vvp_assoc/vpi_darray only, covered by VPI 84/84,
containers 23/23, smoke 14/14, full ivtest fail-list byte-identical)
Highest risk change since last full run: LOW-MEDIUM (SVA lowering
paths in pform.cc + the VPI assoc element write path)

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
