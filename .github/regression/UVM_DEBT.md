# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M11-1/2 head (212/212, 4x53 batches,
2026-07-24 — covered M5-5 MEDIUM-HIGH generic interface ports +
M11-1/2 MEDIUM-HIGH standalone covergroups/sample-dispatch rework).

Commits since full UVM: 3
Highest risk change since last full run: MEDIUM (M11-4 with-function
sample formal binding + package stub-class removal; M11-5 auto-bin
sizing/enum bins/option audit; M11-6 ignore/illegal bin carving +
covergroup registry dedupe in vvp — each covered by coverage 9/9,
classes 25/25, smoke 14/14, full ivtest fail-list byte-identical)

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
