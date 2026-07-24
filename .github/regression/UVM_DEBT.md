# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M12-1 head addb0f1 (212/212, 4x53 batches,
2026-07-24 — the M12B/C VPI-completion MILESTONE head. Validated the
core-SVA lowering touch (every automaton checker now carries per-tick
step flags and two extra report sites) plus the assertion-registration
ABI gaining a flags argument, and M12-3's bit-select force path.)

Commits since full UVM: 0
Highest risk change since last full run: —

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
