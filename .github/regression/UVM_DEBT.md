# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M10-4 head (214/214, 4x batches of 54/54/53/53,
2026-07-24 — validated the DPI-export automatic-lifetime fix. Ran a full
pass because the change allocates and hands off an automatic context in
the export dispatcher, and automatic context lifetime is shared
machinery that UVM leans on heavily.)

Commits since full UVM: 0
Highest risk change since last full run: —

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
