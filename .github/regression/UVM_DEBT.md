# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M9-9 head (212/212, 4x53 batches, 2026-07-24 —
covered M4C-15 MEDIUM + M4C-16 MEDIUM + M9-9 HIGH checker grammar).

Commits since full UVM: 2 (M5-5 MEDIUM-HIGH generic interface ports,
M11-1/2 MEDIUM-HIGH standalone covergroups — the covergroup sample
dispatch was restructured, shared with class-embedded covergroups;
coverage 9/9 + classes 25/25 + smoke 14/14 green). Two consecutive
MEDIUM-HIGH commits: a debt-clearing full run is in flight.
Highest risk change since last full run: MEDIUM-HIGH.

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
