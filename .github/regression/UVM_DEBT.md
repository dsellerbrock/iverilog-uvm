# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M12-8 head b3f3b2b (212/212, 4x53 batches,
2026-07-24 — validated the full accumulated arc since the M11 head:
M9-11 expect, M9-7 D.2 multiclock chains, and the entire M12-4/5/6/7/8
VPI completion cluster: assoc-element writes, nested member
traversal, covergroup drill-down, modport direction metadata, and the
lifetime audit + covergroup-handle leak fix).

Commits since full UVM: 0
Highest risk change since last full run: —

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
