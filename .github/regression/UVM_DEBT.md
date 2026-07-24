# Full-UVM debt tracker (cost-aware regression system)

Full UVM (212 tests, 4x53 batches, ~25-30 min) last passed:
  commit: M3B-4 (this commit — randomize() failure semantics, HIGH risk)
  date: 2026-07-23

Full UVM last passed: M9-9 head (212/212, 4x53 batches, 2026-07-24 —
covered M4C-15 MEDIUM + M4C-16 MEDIUM + M9-9 HIGH checker grammar).

Commits since full UVM: 1 (M5-5 MEDIUM-HIGH generic interface ports —
vif-binding init ordering changed; gated on full ivtest + negative +
sva_nfa + vif 14/14 + classes 25/25 + smoke 14/14).
Highest risk change since last full run: MEDIUM-HIGH.

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
