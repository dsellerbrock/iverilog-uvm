# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M10-1 marshaling head (220/220, 4x55 batches,
2026-07-25 — validated fixed-array marshaling. Ran a full pass because it
adds fields to vvp_darray, which every UVM queue and dynamic array uses, and
a new runtime opcode; the DPI-only reasoning that justified a subset for the
bounds fix does not cover a change to the darray base class.)

Commits since full UVM: 0
Highest risk change since last full run: —

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
