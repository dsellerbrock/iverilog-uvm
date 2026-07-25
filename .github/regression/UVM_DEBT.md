# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: M10-1b head (218/218, 4x batches of 55/55/54/54,
2026-07-25 — validated turning a previously-silent tgt-vvp codegen path into
a hard error. Instrumenting that path and compiling all 218 UVM tests plus
all 1070 ivtest cases had already shown zero hits, but a NEW hard error is
exactly the change where being wrong fails everything, so the full run was
worth its cost as independent confirmation.)

Commits since full UVM: 1
Highest risk change since last full run: LOW — R7 changes svIncrement and
svSizeOfArray in vvp/vvp_dpi.cc plus a tgt-vvp diagnostic wording. Those two
runtime functions are reachable only from a C model that calls them, and
grep shows UVM's own DPI (uvm-core/src/dpi, the umbrella) never references
svIncrement, svSizeOfArray or svOpenArrayHandle at all; the only tests in
the suite using DPI open arrays are the three m10 open-array tests, which
pass. Validated with the dpi subset (16/16) rather than a full run, since a
full run could not exercise anything the subset does not.

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
