# Caliptra first-case runtime fatal triage (2026-09-23)

Read-only inspection of the completed `smoke_test_veer` diagnostic run in
`../caliptra-icarus-l0-diagnostic-aesfix-first-20260923/`. Its `result.json`
records Caliptra `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`, exact firmware
and source integrity, simulation exit 1, zero pass markers, and a reset overlay
with `-gcommercial-unsafe`. No source or live job was changed here.

## Ordered observations

After the ROM boot message, `sim.log:17536` first emits
`ERROR: TLU Flushing inside fast interrupt procedure!`; it repeats at
`:17541`. The `ERR_HWIF_IN` fatal from `soc_ifc_reg.sv:7633` follows at
`:17546-17547`, stamped 43,865,000 ps. A Veer store-buffer assertion error
at `el2_lsu_stbuf.sv:344` is also stamped 43,865,000 ps (`:17548-17549`).
The log does not time-stamp the two TLU messages, so their order relative to
each other and the fatal is known from output order, not exact clock phase.

These three are actual assertion actions. The TLU assertion is a deferred
immediate `assert #0` on
`~((take_ext_int_start_d1 | take_ext_int_start_d2) & dec_tlu_flush_lower_r)`
(`el2_dec_tlu_ctl.sv:1251`). The SOC IFC fatal is the `CALIPTRA_ASSERT_KNOWN`
property on the entire packed `hwif_in` struct, clocked by `clk` and disabled
when `!hwif_in.cptra_pwrgood` (`soc_ifc_reg.sv:7633`; macro in
`src/libs/rtl/caliptra_sva.svh:35-54`). The store-buffer assertion is
`stbuf_specvld_any[2:0] <= DEPTH`, where `DEPTH` is 4 in the pinned
`el2_param.vh:177`. Its count includes committed entries plus M/R speculative
stores (`el2_lsu_stbuf.sv:240-255`). The log does not expose which `hwif_in`
bit was X or the store-buffer count.

The thousands of preceding detailed MLDSA/KV `SVA ERROR` lines are the eager
checker-function side effects documented in
`../caliptra-post-aes-sva-triage-20260923/README.md`. No corresponding outer
assertion failure action appears. They are not evidence that those properties
failed and are separate from the three terminal assertion actions.

The final retired firmware instruction in `exec.log` is `csrs mstatus,a1` at
PC `0x1e60`, cycle 4384. The pinned disassembly places it in
`init_interrupts`, immediately after `csrs mie,a5` at `0x1e5c` and writes
of all ones to timer compare low/high at `0x30030648/64c`. The last LSU AHB
trace cycles 4321-4386 retain address `0x30030648` but show `htrans=0` and
`hready=1`; this is an idle retained address, **not** evidence of a repeated
write or bus stall. The earliest observable terminal invariant violation is
the TLU fast-interrupt flush at interrupt enable. It is plausible that the
following SOC IFC X and store-buffer overflow are related to the same
interrupt transition, but the existing logs cannot establish signal-level
causality or an Icarus semantic defect. An earlier VVP warning at
`sim.log:544` says an undefined dynamic array was written during fuse polling;
the current evidence does not link it to the 43.865 us assertions.

## Narrow copied-source instrumentation for the next authorized replay

Use disposable copies of only three pinned modules in an evidence-local
compile manifest, retaining every original assertion and failure action.
Bound prints to 43.80-43.87 us and the first failure/transition:

1. In `el2_dec_tlu_ctl.sv`, print time, `take_ext_int_start`, its d1/d2
   stages, `dec_tlu_flush_lower_r`, `ext_int_ready`, `block_interrupts`,
   `mstatus`, and `mie` as the fast-interrupt flush predicate first rises.
2. In `soc_ifc_reg.sv`, before the existing known assertion's fatal action,
   print `$isunknown(hwif_in)`, `cptra_pwrgood`, the packed struct in hex,
   and indices of X/Z bits. Map the first unknown bit back to
   `soc_ifc_reg_pkg::soc_ifc_reg__in_t` and then its driver in
   `soc_ifc_top.sv`; avoid guessing from the full-struct fatal.
3. In `el2_lsu_stbuf.sv`, on the overflow predicate print `stbuf_vld`,
   `stbuf_numvld_any`, `stbuf_specvld_m/r/any`, `ldst_dual_m/r`, and the
   M/R store/DCCM predicates. This distinguishes a real count above four
   from X or an assertion scheduling issue.

Pair each suspect with a tiny focused reducer only after the first bad signal
is identified. The present log supports no checker suppression, source fix,
or qualification claim.

## First copied-source overlay

`prepare_diagnostic_overlay.py` verifies SHA-256 of the three pinned modules,
the generated SOC IFC register package, the BFM, and the canonical filelist.
It also verifies that its input filelist is the existing reset overlay with
only the approved `#0 cptra_pwrgood` BFM substitution. It creates a new `/tmp`
directory with copied TLU, SOC IFC, and store-buffer modules, inserts
diagnostic display processes **before** their original assertions, and
redirects exactly three filelist entries (baseline lines 101, 133, 506).
The original assertion statements and failure actions remain byte-identical.
`overlay.json` records input/output hashes and paths. No compiler or simulator
is run by the script.

The TLU and store-buffer monitors print the first failing predicate operands
after reset. The SOC IFC monitor prints the first active-region unknown
`hwif_in`, then the unknown top-level packed members from the pinned
`soc_ifc_reg__in_t` declaration. Because the original SOC IFC property
samples in the preponed region, a same-edge active-region print may differ if
the signal changes during that time slot; compare its output with the fatal
before claiming a particular field caused the property failure.

For one coordinator-controlled replay, prepare the existing reset overlay and
then this overlay. The second command writes only under the new `/tmp` path:

```sh
python3 evidence/caliptra-l0-timezero-reset-overlay-20260923/prepare_overlay.py /tmp/caliptra-runtime-reset-20260923
python3 evidence/caliptra-post-aes-runtime-fatal-triage-20260923/prepare_diagnostic_overlay.py /tmp/caliptra-runtime-reset-20260923/caliptra_top_tb_icarus_profile.vf /tmp/caliptra-runtime-fatal-diag-20260923
```

The resulting substituted filelist is
`/tmp/caliptra-runtime-fatal-diag-20260923/caliptra_top_tb_icarus_profile.vf`;
the three copied modules are under its `source/` directory. To run a single
case after the current gate, from the campaign checkout use a fresh output
directory and the same compiler, flags, firmware, vector assets, DPI module,
and plusargs as the completed diagnostic run:

```sh
export CALIPTRA_ROOT=/Users/danielellerbrock/projects/iverilog_uvm/caliptra-rtl
export CALIPTRA_PRIM_ROOT="$CALIPTRA_ROOT/src/caliptra_prim_generic"
export CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
export CALIPTRA_AXI4PC_DIR="$CALIPTRA_ROOT/src/integration/tb"
mkdir -p /tmp/caliptra-runtime-fatal-replay-20260923/smoke_test_veer
rsync -a --exclude='*.log' --exclude='result.json' evidence/caliptra-icarus-l0-diagnostic-aesfix-first-20260923/smoke_test_veer/ /tmp/caliptra-runtime-fatal-replay-20260923/smoke_test_veer/
local-install/bin/iverilog -g2017 -gassertions -gcommercial-unsafe -s caliptra_top_tb -D RV_OPENSOURCE -D CLP_ASSERT_ON -D CALIPTRA_INTERNAL_TRNG -f /tmp/caliptra-runtime-fatal-diag-20260923/caliptra_top_tb_icarus_profile.vf -o /tmp/caliptra-runtime-fatal-replay-20260923/caliptra_top_tb.vvp > /tmp/caliptra-runtime-fatal-replay-20260923/compile.log 2>&1
(cd /tmp/caliptra-runtime-fatal-replay-20260923/smoke_test_veer && /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/local-install/bin/vvp -d /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/evidence/caliptra-jtagdpi-native-20260923/jtagdpi.vpi -n /tmp/caliptra-runtime-fatal-replay-20260923/caliptra_top_tb.vvp +CLP_REGRESSION +CLP_BUS_LOGS > sim.log 2>&1)
```

The replay's `compile.log` and `smoke_test_veer/sim.log`, plus that directory's
generated `exec.log` and AHB trace, are the diagnostic outputs. Preserve the
nonzero exit and original assertion messages; the copied source is diagnostic
evidence, not a Caliptra L0 qualification run.

## First copied-source replay result

The coordinator's compact [result](first_probe_result.json) and
[exact excerpt](first_probe_excerpt.log) record a first replay with the above
overlay. It exited 1, recorded 621 instruction-trace entries, and kept the original
assertions. At 43,845 ns the TLU probe saw `start=x d1=x d2=0 flush=x
ext_ready=x blocked=x mstatus=1 mie=26`; the original TLU assertion printed
twice. At 43,865 ns SOC IFC reported `CPTRA_HW_ERROR_FATAL=Xa0000000`, and
the store buffer reported `valid=0000 committed=0 spec_m=x spec_r=0 total=x
dual_m=x dccm_m=x`; both original assertions then fired.

The pinned packed type orders the high nibble of `CPTRA_HW_ERROR_FATAL` as
ICCM and DCCM ECC `next,we` pairs (`soc_ifc_reg_pkg.sv:9-24`). Both `next`
signals are tied to one, so one or both ECC write-enables are X. The enables
are `rv_ecc_sts.cptra_{iccm,dccm}_ecc_double_error &
~fw_update_rst_window` (`soc_ifc_top.sv:1377-1378`). The `nmi_pin` and
`crypto_err` fields occupy the known `a` nibble. This narrows the SOC IFC
fatal to either a VeeR ECC output or the firmware reset window, but the first
probe does not distinguish them.

For the TLU, `ext_int_ready` depends on CSR stall, next MIE state, MEIP,
MEIE, and `lsu_fastint_stall_any` (`el2_dec_tlu_ctl.sv:1480`); the latter is
`ld_single_ecc_error_r` from the LSU (`el2_lsu.sv:329`). The flush combines
interrupt, synchronous flush, halt, reset, and fast-interrupt start
(`el2_dec_tlu_ctl.sv:1573`). For the store buffer, `spec_m=x` is derived
from `lsu_pkt_m.valid/store/dma`, `addr_in_dccm_m`, and `ldst_dual_m`
(`el2_lsu_stbuf.sv:248-253`); `ldst_dual_m` compares two M-stage address
bits (`el2_lsu.sv:369`). The narrowest plausible common source is a VeeR
pipeline/ECC state becoming X as interrupts are enabled, but the existing
probes do **not** prove a single shared leaf or a compiler defect. In
particular, an X in the reset window could explain SOC IFC independently.

`prepare_second_probe.py` verifies hashes
of the first overlay's manifest, profile, and three copies plus pinned
`soc_ifc_top.sv`. It copies those three modules and the SOC IFC top into a
new `/tmp` directory, adds only first-event displays for the exact leaf
operands above, and redirects four filelist entries. All original assertion
statements and actions remain intact. From the campaign checkout:

```sh
python3 evidence/caliptra-post-aes-runtime-fatal-triage-20260923/prepare_second_probe.py /tmp/caliptra-runtime-fatal-diag-20260923 /tmp/caliptra-runtime-fatal-second-20260923
```

Its new filelist will be
`/tmp/caliptra-runtime-fatal-second-20260923/caliptra_top_tb_icarus_profile.vf`.
The coordinator used the single-case compile/run recipe above with that
filelist and a fresh `/tmp/caliptra-runtime-fatal-second-replay-20260923/`
output root. The [compact result](second_probe_result.json) and
[excerpt](second_probe_excerpt.log) record exit 1, zero pass markers, 621
instruction-trace entries, and all original assertion actions. The compile
also reports 32 Preponed-region sampling warnings for the separate released
`KV_MLKEM_CHECK0` checker; it cannot qualify as an L0 pass even if the runtime
assertions are repaired.

At 43,845 ns, the TLU inputs are known except `mip[MIP_MEIP]=x`; CSR stall is
0, MIE and MEIE are 1, and the LSU fast-interrupt stall is 0. At 43,865 ns,
`rv_ecc_sts.cptra_iccm_ecc_double_error=x`, while DCCM ECC and the firmware
reset window are 0; the resulting SOC IFC ICCM ECC write-enable is X. The
store-buffer M-stage valid, store, DMA, DCCM-address, and dual-address inputs
are all X. The TLU, SOC IFC, and store-buffer assertions still fire. These
are distinct upstream X paths in the full design; a common cause or an Icarus
semantic defect has not been established. The separate paired packed-field
[reducer](../caliptra-post-aes-soc-partial-reducer-20260923/README.md)
correctly forwards known values and an injected X in both editions.

## Completed third copied-source probe

`prepare_third_probe.py` extends the exact second overlay, whose
`overlay.json` SHA-256 is
`5b83605e00dd1c66999152658429f7be2869ba8bacec80dad534b139005af3f8`
and filelist SHA-256 is
`44122cc02f7c6a3be10af54ef99e780a9f62676ea91ae6eece0ca63ff37d6ab1`.
It guards the four existing copies and three pinned new inputs by SHA-256.
Only copies of `el2_pic_ctrl.sv`, `el2_ifu_mem_ctl.sv`, and
`el2_lsu_lsc_ctl.sv` gain monitors; only their filelist entries (lines 138,
118, and 132) change. At the first observed X between 43,800 and 43,870 ns,
the monitors print compact PIC priority/threshold and first X source index,
IFU ECC enables/results, and LSU packet mux/flop inputs. All original
assertions and other filelist entries remain unchanged.

The coordinator prepared the disposable overlay with:

```sh
python3 evidence/caliptra-post-aes-runtime-fatal-triage-20260923/prepare_third_probe.py \
  /tmp/caliptra-runtime-fatal-second-20260923 \
  /tmp/caliptra-runtime-fatal-third-20260924
```

The profile was
`/tmp/caliptra-runtime-fatal-third-20260924/caliptra_top_tb_icarus_profile.vf`.
The completed single-case run used a fresh
`/tmp/caliptra-runtime-fatal-third-replay-20260924/` output directory. Its
[result](third_probe_result.json) records the overlay manifest, profile,
compiled VVP, compile log, simulator log, and instruction trace SHA-256
values; the [excerpt](third_probe_excerpt.log) retains the causal signals and
original assertion actions. The earlier compiler/VVP pair emitted 32
Preponed-region sampling warnings. Runtime exited 1 with zero pass markers
after 621 firmware instruction-trace entries. This is diagnostic evidence
under `-gcommercial-unsafe`, not an L0 pass or IEEE qualification.

At 43,805 ns, the first PIC monitor showed `pending=x`,
`pending_in=x`, and `selected_int_priority=z`, while its 32 checked leaf
priorities were known and the threshold, current priority, and invert input
were zero. The pinned `el2_pic_ctrl.sv:464-466` compares that priority with
both zero thresholds, then registers the resulting X into `mexintpend`;
`el2_dec_tlu_ctl.sv:1704` places `mexintpend` into `mip[MIP_MEIP]`. This
source-level chain matches the TLU `mip[MIP_MEIP]=x` observation at 43,845 ns
and the IFU, SOC IFC, and store-buffer X observations at 43,865 ns. The
original TLU flush assertion printed twice; the original SOC IFC known-value
fatal and store-buffer overflow assertion also fired. The PIC priority Z is
the earliest known-operand error in this probe. The full-design replay alone
does not prove the later IFU/SOC/LSU X signals all descend from PIC.

## Packed partial-driver reduction and selected compiler path

The pinned `el2_pic_ctrl.sv:405-431` builds a nested packed priority tree
with disjoint continuous assignments. The copied-shape
[priority reducer](pic_priority_tree_reducer.sv) drives 32 known-zero leaves:
the installed Icarus binary produces `l0=zzzz` through `l5=zzzz` and exits 1
in both 2017 and 2023 modes. A whole-array assignment control and a
single-driver control pass. The smaller
[disjoint reducer](packed_disjoint_continuous_min.sv) preserves independent
disjoint slices but loses both slices when the second driver reads the first.

`PGAssign::elaborate` and `PEIdent::elaborate_lnet_common_` lower the selected
lvalues to `NetPartSelect::PV` drivers. `cprop_functor::lpm_part_select` in
`cprop.cc` blends nonoverlapping PV drivers into one `NetConcat`. Its output
then feeds an input of that same concat through the packed VP read and
comparison tree, forming a zero-time structural feedback cycle; a generated
VVP excerpt shows both `.part` source and concat destination on the same
packed nexus. A guard limited to direct VP reads misses the separate
[uncovered whole-vector reduction](packed_whole_read_cycle_min.sv), which
reads `|dependent` and yields `zzz` instead of `z11` in both editions.

The selected private candidate checks combinational reachability from the
partial-driver destination nexus to each candidate PV input before blending.
It follows only node input-to-output links, records visited nexuses, and
stops at `NetFF`. It leaves ordinary unrelated readers blended. The paired
[results](pic_reducer_results.json) show the PIC tree, dependent disjoint
slices, and uncovered whole-vector reduction changing from runtime RED to
PASS in both editions. The dedicated
`ivtest/ivltests/sv_packed_partial_feedback.v` fixture covers dynamic nested
feedback, an unrelated whole-vector reader, a single partial driver into a
two-state destination, and registered feedback. The latter two boundaries
pass before and after the candidate in both editions; `-S -N` shows an
`LPM_FF` on the registered feedback path and `NetConcat` retained for those
non-combinational cases. The paired overlap-negative fixture remains a
compile error in both editions. Target `uwire` multi-driver warnings remain
on the preserved legal partial drivers; they are recorded in the results,
not suppressed.

The separate [fully covered whole-vector reducer](packed_whole_read_covered_min.sv)
remains RED (`zz` rather than `11`) with the candidate in both editions.
Its direct `elab_net.cc` to `netmisc.cc:collapse_partselect_pv_to_concat`
path folds before cprop can guard the PV drivers. That is a distinct
elaboration blocker outside the selected `cprop.cc` source scope. The
private full Caliptra top compile-only comparison (`-tnull`, unsafe profile)
exited zero on both binaries with the same 24 existing warnings: one measured
pair took 7.22 seconds installed and 6.39 seconds candidate wall time. It
shows no observed compile penalty in this pair, without establishing a
performance benchmark. The coordinator owns shared installation and the
exact released first-case replay.

## VVP compile crash and null-output correction

The first shared VVP compile after PIC integration exited 139 before runtime.
The macOS crash report puts the null dereference in `Nexus::first_nlink()`
under the new `cprop_functor::lpm_part_select` reachability walk. A connected
combinational node may have other, unconnected output pins, and
`const Link::nexus()` returns null for those pins. The original walk queued
those nulls. This was a guard bug, not a VVP target failure.

The paired positive fixture now adds an unrelated comparison of the
partially driven independent destination. Its unused comparator outputs
reproduce compile exit 139 with the first installed PIC compiler; the
corrected private compiler skips null PV inputs and null node outputs,
compiles, and runs the fixture. The private paired JSON focus passes 4/4,
and the exact PIC tree passes runtime in 2017 and 2023 modes. The
[null-output result](pic_nullguard_result.json) records source and compiler
hashes, exact commands, exits, and logs under `/tmp`.

With the corrected private compiler, the exact pinned unsafe full-top VVP
compile exited zero and emitted a 339 MB VVP; no L0 runtime was attempted in
this probe. The compile retained 24 existing warnings plus two PIC `uwire`
warnings. It also printed two target limitations at
`caliptra_top_tb_services.sv:2355-2356`:
`vvp.tgt sorry: procedural continuous assignments are not yet fully supported.
The RHS of this assignment will only be evaluated once, at the time the
assignment statement is executed.` Those diagnostics remain active and may
affect runtime qualification; they were not suppressed.

The preserved partial drivers also expose a `uwire` multi-driver warning in
the existing `sv_packed_mixed_driver_compound` regression. Its runtime checks
still pass; the legacy and JSON gold files record the exact warning rather
than hiding it. Focused legacy 1/1 and paired 2017/2023 JSON 2/2 pass. This
warning remains a target diagnostic debt, separate from the runtime-correct
partial-driver fix.
