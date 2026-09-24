# OpenTitan and Caliptra release overlays

In this campaign, **released OpenTitan** and **released Caliptra** mean the
pinned release sources below, plus the known-needed patches and documented run
options selected for the named DV test. Name that test in each result: there
is no one global patch or option set. This shorthand does not mean either full
DV suite passes.
Keep the pinned checkouts pristine; apply overlays only to disposable source
copies and record unmodified-source results separately.

| Application | Pinned source |
| --- | --- |
| OpenTitan | `Earlgrey-PROD-M6`, `a78922f14a8cc20c7ee569f322a04626f2ac6127` |
| Caliptra | `v2.1.2`, `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e` |
| Caliptra's Adams Bridge submodule | `v2.0.3`, `b77e3d899e828d626cfc2a0d26a6b5704cc121e0` |

## Known-needed source patches

| Test and disposition | Patch relative to application root | Evidence |
| --- | --- | --- |
| OpenTitan `pwrmgr_smoke_vseq`, seed 3: apply the clock-activity checker correction. The generated checker is used in simulation; the template is patched so regeneration keeps the correction. | [pwrmgr_clock_activity.patch](opentitan/pwrmgr_clock_activity.patch) | [Seed-3 revalidation](../session_logs/2026-09-21_pwrmgr_seed3_upstream_revalidation.json) and [focused checker run](../session_logs/2026-09-21_pwrmgr_seed3_checker_fix.json). Pristine seed 3 fails. |
| OpenTitan CSRNG `csrng_sim`: replace two nonstandard instance-hierarchical indexed part-select widths with a testbench-local constant matching the released core's 128-bit block length. | [csrng_blklen_width.patch](opentitan/csrng_blklen_width.patch) | [Disposable-copy compile and configured smoke](../../../evidence/opentitan-csrng-blklen-overlay-20260923/smoke-replay.json). Compile exits 0; smoke aborts before UVM at `vvp/array.cc:483`, and semantic warnings remain. |
| Caliptra Adams Bridge `rej_bounded_tb`: apply the scoreboard/zeroize ordering correction. | [rej_bounded_tb.patch](caliptra/rej_bounded_tb.patch) | [Paired pinned-release replay](../session_logs/2026-09-23_caliptra_rej_bounded_race_fix.json) and [upstream PR 303](https://github.com/chipsalliance/adams-bridge/pull/303). Pristine unit run fails. |
| Caliptra `fv_ecc_dsa_sequencer.sv` formal filelist only: correct an undeclared `DSA_NOP` to the package's `ECC_NOP`. This is required to compile this selected released formal file and is not a DV-test patch. | [ecc_dsa_nop_formal.patch](caliptra/ecc_dsa_nop_formal.patch) | [Pristine failure and patched-copy paired compile](../session_logs/2026-09-23_caliptra_ecc_nop_overlay.json). No formal proof or DV runtime is claimed. |
| Caliptra `iccm_lock`: gate detailed key-vault mismatch output to the assertion failure action, avoiding eager consequent-function diagnostics on a false antecedent while preserving the assertion predicate and failure details. | [kv_debug_check_pure.patch](caliptra/kv_debug_check_pure.patch) | [Focused checker and pinned replay](../session_logs/2026-09-23_caliptra_kv_sva_overlay_l0.json). Diagnostic evidence only; no full L0 or Caliptra DV qualification. |
| Caliptra `smoke_test_hw_config` only: give its C11 interrupt helper internal linkage (`static inline`). | [hw_config_inline_c11.patch](caliptra/hw_config_inline_c11.patch) | [Pinned baseline and focused patched-copy replay](../../../evidence/caliptra-exact-l0-20260923/README.md). Firmware builds and simulation passes with the patch; the pristine build has an undefined reference. |
| Caliptra `smoke_test_hmac_errortrigger` only: include the standard header declaring `srand`. | [hmac_errortrigger_stdlib.patch](caliptra/hmac_errortrigger_stdlib.patch) | [Pinned baseline and focused patched-copy replay](../../../evidence/caliptra-exact-l0-20260923/README.md). Firmware builds and simulation passes with the patch; the pristine build rejects the implicit declaration. |

The [OpenTitan xbar `dv_report_catcher` patch](opentitan/dv_report_catcher_foreach.patch)
is **conditional historical evidence**, not part of the default xbar profile.
The September 15 passing run used it to replace nonstandard `foreach` syntax;
a later bounded xbar smoke passed with this source unmodified. See the
[original run](../session_logs/2026-09-15_opentitan_xbar_smoke_patched.md)
and [release replay](../session_logs/2026-09-21_qualified_nine_release_retest.json).

Each file is a frozen copy of the patch used in its linked evidence. From the
compiler worktree, validate and apply a selected patch to a **disposable copy**
of the corresponding application root with `patch --dry-run -p1 -d "$APP_COPY"
-i "$PATCH"`, followed by the same command without `--dry-run`. Do not apply
the patches to the pinned checkouts. The SHA-256 values are
`dc4c9b4be456a842e34c41cb002972762395ac0952bcef153d3bca7b4e9af8ec`
for pwrmgr, `dec3ee052af0122b4c90e86a47aa5421e1222f73608bddbe9bbb5cb979494a45`
for rej_bounded, and `9213d50c02d9477a16a66daa744bb906b69e3634de7ad1955f5d879f4fcfbb3d`
for the conditional xbar patch.
The ECC formal patch SHA-256 is
`3bfc6a88737471f79d7344fb1fb5c588a63ca22789e3cdbb66a40652da98215e`.
The `smoke_test_hw_config` patch SHA-256 is
`36aa05fef48b9358556ffd67bcfa9c6f6e62dcbeee20607ef3fb8cb36f664a9c`;
the `smoke_test_hmac_errortrigger` patch SHA-256 is
`ed5e27f4b6806a22373943030d31b84396535f21b8d6ef96b8d527ef4efed621`.
The pinned CSRNG width patch SHA-256 is
`04dd45643a684aa69ce1a94e67275c9ad0695a7251958ea893579a441901772d`.

## Selected run options

These are the settings used by the cited runs, not a claim that every listed
switch is necessary for every test. Use the current worktree's `iverilog` and
`vvp`, and preserve each run's exact compiler/source fingerprints in its
evidence.

| Target | Options and status |
| --- | --- |
| OpenTitan xbar/pwrmgr UVM smoke | FuseSoC source generation with the pinned OpenTitan Python environment; `iverilog -g2012 -uvm --uvm-home=<pinned UVM 1.2 src>` plus the core's bind roots and UVM/DUT defines; `vvp -n` with `+smoke_test=1` and the target's `+UVM_TESTNAME` / `+UVM_TEST_SEQ`. The [matrix runner](../opentitan_matrix.md) owns setup and full commands. Keep `+timescale+1ns/1ps` in the pwrmgr compiler command file: omitting it invalidates the replay by turning source delays into zero-time delays. The pwrmgr seed-3 overlay replay additionally used `+ntb_random_seed=3`, `+test_timeout_ns=1000000`, and `-DUVM_REGEX_NO_DPI`; its separate focused checker tests exercised both NFA modes. [Current-head seeds 1 and 3](../session_logs/2026-09-23_pwrmgr_release_overlay_current.json) passed with the timescale option. Consult the evidence before rerunning. |
| OpenTitan CSRNG `csrng_sim` compile | Apply the CSRNG width patch only to a disposable copy of Earlgrey-PROD-M6 `a78922f14a8cc20c7ee569f322a04626f2ac6127`. The [exact command](../../../evidence/opentitan-csrng-blklen-overlay-20260923/replay.json) uses `-g2017 -gcommercial-unsafe -stb -scsrng_cov_bind -uvm`, the pinned UVM 1.2 source, UVM/DUT defines, and FuseSoC's generated CSRNG filelist. Compile exit 0 does not establish simulation correctness: the monitor event is skipped and a constraint item is ignored. |
| OpenTitan SPI Host | Carry upstream's `-DUVM_REGEX_NO_DPI` from `common_sim_cfg.hjson` into the Icarus compile; it selects UVM's SystemVerilog glob matcher for patterns such as `*_shadowed`. Keep the normal real-DPI bundle for other UVM functions. Add `-gcommercial-unsafe` **only** when testing the opt-in packed `bit`/`logic` queue conversion. It clears the strict type errors. The [selected-bit NBA candidate](../session_logs/2026-09-23_opentitan_nba_codegen_focus.json) removes five target errors, and the later [queue-pop candidate](../session_logs/2026-09-23_opentitan_queue_pop_focus.json) removes that dropped expression in a pinned compile. Four constraint-index references still degrade semantics. With the regex option, the earlier pinned smoke reached a VIF event-relay runtime abort; SPI DV is not qualified. The [regex configuration record](../session_logs/2026-09-21_opentitan_regex_configuration.json) explains the required option. |
| OpenTitan ADC Control `adc_ctrl_sim` | No source overlay is selected. The [pinned target result](../session_logs/2026-09-23_opentitan_adc_macro_arg_focus.json) uses FuseSoC's generated source list, `-g2012 -uvm` with pinned UVM 1.2, and the target's UVM, DUT, and bind options. Metadata selects `adc_ctrl_base_test` / `adc_ctrl_smoke_vseq` with `+smoke_test=1`. The macro and [guarded-distribution](../session_logs/2026-09-23_opentitan_adc_guarded_dist_fileset_focus.json) fixes advance the smoke to [nested dynamic-array resize](../BLOCKERS.md), which VVP mislabels as class-handle resizing. No ADC DV pass is claimed. |
| Caliptra Adams Bridge `rej_bounded_tb` | `iverilog -g2012 -gassertions -s rej_bounded_tb -f <pinned filelist>` and `vvp <image> +VEC_CNT=100`. Use the [pinned filelist, fixed seed prefix, Python 3, and fresh run directory](../repros/caliptra_rej_bounded/README.md). This unit replay needs no DPI bundle or timescale override. |
| Caliptra ECC formal filelist | Select the one-file ECC overlay on a disposable copy. Compile with `-g2017` or `-g2023`, `-gassertions -tnull -s ecc_top -f <pinned>/src/ecc/config/ecc_top.vf` plus the patched formal property file; set the pinned Caliptra and Adams Bridge roots as in the [exact compile record](../session_logs/2026-09-23_caliptra_ecc_nop_overlay.json). Both editions compile, but this is not formal proof or DV runtime. |
| Caliptra PM formal filelist | No source overlay is selected. The clean pinned `fv_ecc_pm_sequencer.sv` compiles in both editions with `-gassertions -tnull -s ecc_top` and the pinned ECC filelist on the [integrated compiler tree](../session_logs/2026-09-23_caliptra_pm_integrated_compile.json). This is compile evidence, not formal proof or DV runtime. |
| Caliptra `iccm_lock` diagnostic replay | Verilator `-Wno-MISINDENT` with the selected `kv_debug_check_pure.patch`; this is the only warning option used. The [session record](../session_logs/2026-09-23_caliptra_kv_sva_overlay_l0.json) documents the pinned-source result and its multilib caveat. |
| Caliptra selected Verilator L0 tests | The [52-case exact-toolchain baseline](../../../evidence/caliptra-exact-l0-20260923/README.md) used official xPack GCC 15.2.0-1 with `rv32imc/ilp32`, `BUILD_CFLAGS=-std=gnu11 -O2`, `CALIPTRA_INTERNAL_TRNG=1`, `PLAYBOOK_RANDOM_SEED=1`, Verilator 5.050 with `-Wno-MISINDENT`, `+CLP_REGRESSION`, and the KV diagnostic overlay. Apply each C overlay above only for its named test. The baseline is 49/52; both firmware fixes pass focused replays. `smoke_test_doe_scan` still emits a real SVA error despite its exit 0 and pass banner. No patched full-suite rerun or full DV qualification. |
| Caliptra integration tests | Keep `+timescale+1ns/1ps` in the appropriate Icarus command file. For a test requiring real DPI, load its bundle with the matching `vvp -d <bundle>`; see [UVM/DPI usage](../../uvm.md). These settings do not establish a full Caliptra DV pass. |

Current qualification and unresolved compiler blockers are in
[CURRENT_WORK](../CURRENT_WORK.md) and [BLOCKERS](../BLOCKERS.md). No source
overlay is an acceptable substitute for a missing compiler semantic fix.

The latest scoped [pwrmgr case-exit replay](../session_logs/2026-09-23_pwrmgr_case_exit_stack_balance.json)
uses the same selected checker overlay and run options; consult that
revision-scoped record when comparing application results.
