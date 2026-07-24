# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M12-2 head f21cb21 (212/212, 4x53 batches,
2026-07-24 — validated the SVA assertion-ABI change: attemptStartTime
recovery via depth_arg threaded through $ivl_register_assertion and
the __vpiAssertion start-time ring; ran a full pass because it touches
the core SVA lowering + assertion VPI ABI, not just VPI read paths).

Commits since full UVM: 0
Highest risk change since last full run: —

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
