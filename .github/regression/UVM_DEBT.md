# Full-UVM debt tracker (cost-aware regression system)

Full UVM (212 tests, 4x53 batches, ~25-30 min) last passed:
  commit: 98f50a1 (M4C-2/3/4)
  date: 2026-07-23

Commits since full UVM: 3 (c9d5204 M4C-5 MEDIUM, a44c0b5 infra LOW, M4C-7a MEDIUM)
Highest risk change since last full run: MEDIUM — M4C-7a array-word slice codegen (Tier2 containers + smoke green)

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
