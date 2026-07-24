# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M6B-4 head (216/216, 4x54 batches, 2026-07-24 —
validated the Preponed-sampling change. Ran a full pass because it
rewrites the operand reads of EVERY synthesized concurrent assertion and
touches system-function width/type determination in elaboration, both of
which reach far beyond the assertion itself.)

Commits since full UVM: 0
Highest risk change since last full run: —

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
