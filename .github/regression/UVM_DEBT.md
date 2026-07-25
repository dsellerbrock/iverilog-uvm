# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M10-1b head (218/218, 4x batches of 55/55/54/54,
2026-07-25 — validated turning a previously-silent tgt-vvp codegen path into
a hard error. Instrumenting that path and compiling all 218 UVM tests plus
all 1070 ivtest cases had already shown zero hits, but a NEW hard error is
exactly the change where being wrong fails everything, so the full run was
worth its cost as independent confirmation.)

Commits since full UVM: 0
Highest risk change since last full run: —

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
