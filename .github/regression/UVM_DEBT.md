# Full-UVM debt tracker (cost-aware regression system)

Full UVM (212 tests, 4x53 batches, ~25-30 min) last passed:
  commit: M4C-8 (this commit)
  date: 2026-07-23

Commits since full UVM: 5 (M4C-9 MEDIUM, M4C-6 LOW, M4C-9b LOW, M11-7 MEDIUM, M4C-11 MEDIUM)
Highest risk change since last full run: MEDIUM — M4C-11 inside-operator property containers, new %inside/arr/o opcode (constraints 22/22 + smoke 14/14 + full ivtest green)

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
