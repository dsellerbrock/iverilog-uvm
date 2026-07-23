# Full-UVM debt tracker (cost-aware regression system)

Full UVM (212 tests, 4x53 batches, ~25-30 min) last passed:
  commit: M3B-4 (this commit — randomize() failure semantics, HIGH risk)
  date: 2026-07-23

Full UVM last passed: M4C-14 head (212/212, 4x53 batches, 2026-07-23 —
covered M4C-12 HIGH + M4C-13 MEDIUM + M4C-14 HIGH).

Commits since full UVM: 2 (M4C-15 MEDIUM mailboxes, M4C-16 MEDIUM
streaming-to-unpacked; both gated on full ivtest + negative + sva_nfa +
uvm_seq_tlm 5/5 + containers 23/23 + smoke 14/14).
Highest risk change since last full run: MEDIUM.

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
