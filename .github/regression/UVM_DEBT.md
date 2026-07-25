# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M10-1c head (220/220, 4x55 batches, 2026-07-25 —
validated an assignment type check added to elaborate_rval_expr. That
function runs for EVERY assignment in every design, so a false positive
there would fail broadly rather than narrowly; a full run is the only way to
show UVM has no pattern the new check misreads.)

Commits since full UVM: 0
Highest risk change since last full run: —

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
