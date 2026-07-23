# Full-UVM debt tracker (cost-aware regression system)

Full UVM (212 tests, 4x53 batches, ~25-30 min) last passed:
  commit: M3B-4 (this commit — randomize() failure semantics, HIGH risk)
  date: 2026-07-23

Commits since full UVM: 1 (M4C-12 HIGH)
Highest risk change since last full run: HIGH — M4C-12 queue literal/pattern
codegen rework (containers 23/23 + classes 25/25 + smoke 14/14 + full
ivtest green). One more HIGH commit triggers a full run.

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
