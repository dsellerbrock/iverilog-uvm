# Integration tabs (2026-10-01 consolidation)

One iverilog-uvm branch carries all fixes. Worktree/branch clones were retired; this file tracks what was brought in and
what is still NOT wired. Update it as items are finished. Standing rule: at most 3 iverilog-uvm clones, 1 OpenTitan, 1 Caliptra.

## Source branches
| Branch | State | Notes |
|---|---|---|
| agent/ot-alert-foreach, ot-ibex-clocking-edge, ot-ibex-generated-covergroup, ot-ibex-sva-match-item, sysrst-fork-disable | integrated | patch-equivalent commits already in this line; merged `-s ours` |
| agent/ot-rv-dm-std-randomize | integrated | one missing commit ported by hand (Boolean operands of bitwise constraint operators) |
| agent/concat-select-container, docs/opentitan-xbar-smoke-patched, agent/sva-matchitem-lvalue-select, docs/concise-readme, agent/uarray-slice-port, agent/ot-lc-combined-integration | integrated | added lines 100% present; merged `-s ours` |
| agent/caliptra-memory-cap, agent/caliptra-l0-sweep | merged | Caliptra L0 runner (evidence/caliptra-icarus-l0-runner-20260923); compiler hunks were already present |
| agent/l106-l116-regression-fix-20260915 | PARTIAL | merged; SVA multiclock first_match prefix work and ~164 of 204 added tests pass. See pending list below |
| worktree campaign-20260908 (untracked) | integrated | wildcard-import class-member tests brought in and a real lookup bug fixed (pform.cc); AGENTS.md routing text and focus lists dropped |

## Pending integration (tests in `ivtest/regress-pending-integration-{sv,vvp}.list`, not run by gates)
From agent/l106-l116-regression-fix-20260915; their solver/covergroup code was dropped where it conflicted with newer work:
1. `sv_constraint_wide_fixed_element_*` and `sv_constraint_nested_fixed_element_wide` (wide >64-bit fixed-array elements in constraints,
   `C:` wide constant terminal in constraint IR, dist over wide elements). The nested (<=64-bit) `x:` element path is integrated
   (2026-10-01): `parse_nested_elem` in vvp_z3.cc, plus `:t` state-read flavor for non-random handles.
2. ~~`sv_cov_ctor_transition_*`~~ DONE 2026-10-01: elaborate.cc dynamic-term hunk re-applied on top of HEAD's ctor_range_* helpers; static terms in a
   constructor-dependent family ship as constant IR. Moved into regress-sv/vvp.list. Remaining pending: wide fixed element (item 1),
   sv_joint_coupled_randc_ordered_*. sv_implicit_property_method_collision_generic_fail is DONE (`Name::m()` no longer resolves a variable).
Re-integrate against current vvp_z3.cc/elaborate.cc, then move the entries back into regress-sv.list/regress-vvp.list.

## Known gaps (not from branches)
- rand 2-D dynamic arrays (`rand T f[][]`, `f[c].size`, `foreach (f[c,i])`): OpenTitan adc_ctrl.
- fixed arrays of containers as `ref`/aggregate (tgt-vvp uarray_container_kind_ has no container leaf): OpenTitan flash_ctrl.
- covergroup `bins x = {[0:ctor_arg]} with (...)`: OpenTitan i2c.
- function-call `ref` actuals that are dyn-array/queue/fixed-array elements still copy in/out (task path binds them).
- hmac scoreboard race (wait_clks vs same-edge counter update), OpenTitan otbn needs +otbn_elf_dir, spi_tpm TB passes a parameter the RTL lacks.
- Legacy gate for the commits up to 4cfcc2798 was not fully completed; JSON 4228/0 and UVM 363/0 were.

## Patches
`~/projects/iverilog_uvm/patches/{opentitan,caliptra,caliptra-runner-from-branches}`; the OT/Caliptra overlays are also tracked in
docs/conformance/release_overlays/.
