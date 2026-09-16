# OpenTitan `xbar_smoke` — first passing UVM test, patched release (2026-09-15)

## ⚠️ Status: patched-release evidence, not an unmodified-source pass

`opentitan_dirty: true`. This result required one single-file source
correction to OpenTitan (`hw/dv/sv/dv_utils/dv_report_catcher.sv`). It is
recorded here **for visibility, not as satisfaction of application
objective 5** ("make unmodified OpenTitan ... fully usable"). The
unmodified-source path for this same test still fails (see below), and
that failure is retained, not overwritten.

## Result

- Target: **Earlgrey-PROD-M6**, OpenTitan commit
  `a78922f14a8cc20c7ee569f322a04626f2ac6127`
  (`clean-corpora/opentitan-7a3ad34` — directory name is historical, the
  commit is authoritative).
- Core: `lowrisc:dv:top_earlgrey_xbar_peri_sim:0.1`
- Test: `xbar_smoke` — UVM test `xbar_base_test`, vseq `xbar_smoke_vseq`,
  target `sim`, top `xbar_tb_top`.
- Generated: `2026-09-15T19:40:22Z`.
- Icarus: `13.0 (devel)`, compiler engine SHA-256
  `6ee57dbff385f5a06bf876f69654fb037494aa771f6d331c385078a13ef4e2a9`.

```
Status counts: PASS=1   (hard errors 0, semantic debt 0)
Number of demoted UVM_FATAL reports  :    0
Number of demoted UVM_ERROR reports  :    0
Number of caught UVM_FATAL reports   :    0
Number of caught UVM_ERROR reports   :    0
Quit count :     0 of    50
UVM_ERROR : 0   UVM_FATAL : 0
TEST PASSED CHECKS
```

Full log:
`evidence/application-check-20260915/stable-baseline/opentitan-minimal-foreach-fix/matrix/runtime/lowrisc_dv_top_earlgrey_xbar_peri_sim_0.1/matrix-runtime.log`.
Matrix summary:
`evidence/application-check-20260915/stable-baseline/opentitan-minimal-foreach-fix/result.json`
/ `result.md`.

## The patch, and why it was applied

File: `hw/dv/sv/dv_utils/dv_report_catcher.sv`. Original syntax:

```systemverilog
foreach (m_changed_sev[id][msg]) begin
  if (uvm_re_match(msg, report_msg)) begin
    set_severity(m_changed_sev[id][msg]);
```

`m_changed_sev` is a 2-D associative array (`string` inner key over a
`string` outer key). `id` here is a **runtime** value, not a constant —
this is not `foreach (arr[a][b])` selecting two loop variables of one
array; it is one loop variable (`msg`) with a **runtime index-select**
(`[id]`) placed in front of it.

IEEE 1800-2017 §12.7.3 (Syntax 12-5) requires
`ps_or_hierarchical_array_identifier [ loop_variables ]`; Annex A defines
the hierarchical identifier's intervening selects as `constant_bit_select`.
A runtime-valued intervening select is therefore **not standard `foreach`
syntax** in either the 2017 or 2023 edition (2023 §12.7.3, same
requirement). This was checked directly against the LRM text before
concluding anything — see
`evidence/application-check-20260915/stable-baseline/opentitan-release-layout/foreach-assessment/assessment.md`.

**Conclusion: this is upstream nonstandard syntax, not an Icarus semantic
gap.** Teaching Icarus to accept it as an extension was considered and
explicitly rejected — it would require parser and `foreach`-elaboration
changes to admit non-constant intervening selects, which is not a
conformance repair; it would make Icarus accept invalid syntax silently.

The applied patch changes the loop shape to two genuine loop variables
over the (now single, 2-D) associative array, with the `id` comparison
moved into the loop body:

```diff
-      foreach (m_changed_sev[id][msg]) begin
-        if (uvm_re_match(msg, report_msg)) begin
-          set_severity(m_changed_sev[id][msg]);
+      foreach (m_changed_sev[changed_id, msg]) begin
+        if (changed_id == id) begin
+          if (uvm_re_match(msg, report_msg)) begin
+            set_severity(m_changed_sev[changed_id][msg]);
+          end
         end
       end
```

Authorization: "User permits absolutely necessary honest application
fixes; invalid foreach syntax prevents compile" — this was the blocking
compile failure standing between the entire xbar_smoke UVM run and any
result at all; without it, the run does not reach `TEST PASSED CHECKS` or
any other conclusion, patched or not.

## Preserved evidence (so this is auditable, not just asserted)

All under
`evidence/application-check-20260915/stable-baseline/opentitan-release-layout/foreach-assessment/upstream-fix/`:

- `original-dv_report_catcher.sv` — the untouched original file.
- `dv_report_catcher-foreach.patch` — the exact diff applied.
- `applied.json`:
  - `original_sha256: 2716effd0705551c170c439cbdbadb0e242faee842f30e584a5b2450f1c9d5ac`
  - `patched_sha256: f5af465b96f901dc9bece1882f2ec43e6a325ec9edee7d3603908def997d4282`
  - `patch_sha256: 9213d50c02d9477a16a66daa744bb906b69e3634de7ad1955f5d879f4fcfbb3d`

Positive/negative oracles proving the assessment (not just asserting it):

- `foreach_multidim_legal.sv` — the **patched** spelling
  (`foreach (arr[changed_id, msg])`, two loop variables, one 2-D array) is
  positively legal; must print `PASSED id hit` exactly once. Passes in
  both `-g2017` and `-g2023`.
- `foreach_indexed_subarray_invalid.sv` — the **original** spelling
  (`foreach (arr[id][msg])`, a runtime index-select before the loop-
  variable bracket) must be rejected at compile time, and must never
  print `UNREACHABLE`. Rejected as expected in both editions.

## What this is not

- Not an unmodified-OpenTitan pass. Application objective 5 remains
  unmet for this core until either (a) this fix is upstreamed to lowRISC
  and lands in a future OpenTitan release, or (b) a different core/test
  whose sources are already standards-clean is used to demonstrate the
  unmodified path.
- Not a claim that Icarus's `foreach` support is complete. See
  `docs/conformance/DISCOVERED_DEBT.md`'s "Iteration" row for a
  *different*, still-open `foreach`/§12.7.3 question (a 1-D associative
  array of structs given two loop variables — a loop-variable-count-vs-
  dimension question, not a runtime-index-select question; the two are
  not the same defect and are tracked separately).
