# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M11 milestone-COMPLETE head 3d70294 (212/212,
4x53 batches, 2026-07-24 — covered M11-3/4/5/6: with-function sample,
package stub-class removal, auto-bin sizing/enum bins, ignore/illegal
carving, registry dedupe, and class-embedded event sampling with the
new %covgrp/sample/all runtime).

Commits since full UVM: 6 (ivl.def Windows exports; M9-11 expect;
M9-7 D.2 multiclock chains; M12-4 assoc VPI writes; M12-5 nested VPI
members; M12-7 covergroup VPI drill-down — VPI/coverage metadata
only, covered by VPI 86/86, coverage 9/9, smoke 14/14, full ivtest
fail-list byte-identical)
Highest risk change since last full run: LOW-MEDIUM (SVA lowering
paths in pform.cc + VPI object/array/coverage access paths).
NOTE: 2 more stable commits reach the 8-commit full-UVM trigger.

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
