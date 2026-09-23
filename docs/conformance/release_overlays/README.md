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
| Caliptra Adams Bridge `rej_bounded_tb`: apply the scoreboard/zeroize ordering correction. | [rej_bounded_tb.patch](caliptra/rej_bounded_tb.patch) | [Paired pinned-release replay](../session_logs/2026-09-23_caliptra_rej_bounded_race_fix.json) and [upstream PR 303](https://github.com/chipsalliance/adams-bridge/pull/303). Pristine unit run fails. |

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

## Selected run options

These are the settings used by the cited runs, not a claim that every listed
switch is necessary for every test. Use the current worktree's `iverilog` and
`vvp`, and preserve each run's exact compiler/source fingerprints in its
evidence.

| Target | Options and status |
| --- | --- |
| OpenTitan xbar/pwrmgr UVM smoke | FuseSoC source generation with the pinned OpenTitan Python environment; `iverilog -g2012 -uvm --uvm-home=<pinned UVM 1.2 src>` plus the core's bind roots and UVM/DUT defines; `vvp -n` with `+smoke_test=1` and the target's `+UVM_TESTNAME` / `+UVM_TEST_SEQ`. The [matrix runner](../opentitan_matrix.md) owns setup and full commands. The pwrmgr seed-3 overlay replay additionally used `+ntb_random_seed=3`, `+test_timeout_ns=1000000`, and `-DUVM_REGEX_NO_DPI`; its separate focused checker tests exercised both NFA modes. Consult the evidence before rerunning. |
| OpenTitan SPI Host | Carry upstream's `-DUVM_REGEX_NO_DPI` from `common_sim_cfg.hjson` into the Icarus compile; it selects UVM's SystemVerilog glob matcher for patterns such as `*_shadowed`. Keep the normal real-DPI bundle for other UVM functions. Add `-gcommercial-unsafe` **only** when testing the opt-in packed `bit`/`logic` queue conversion. It clears the strict type errors. The [selected-bit NBA candidate](../session_logs/2026-09-23_opentitan_nba_codegen_focus.json) removes five target errors, and the later [queue-pop candidate](../session_logs/2026-09-23_opentitan_queue_pop_focus.json) removes that dropped expression in a pinned compile. Four constraint-index references still degrade semantics. With the regex option, the earlier pinned smoke reached a VIF event-relay runtime abort; SPI DV is not qualified. The [regex configuration record](../session_logs/2026-09-21_opentitan_regex_configuration.json) explains the required option. |
| Caliptra Adams Bridge `rej_bounded_tb` | `iverilog -g2012 -gassertions -s rej_bounded_tb -f <pinned filelist>` and `vvp <image> +VEC_CNT=100`. Use the [pinned filelist, fixed seed prefix, Python 3, and fresh run directory](../repros/caliptra_rej_bounded/README.md). This unit replay needs no DPI bundle or timescale override. |
| Caliptra integration tests | Keep `+timescale+1ns/1ps` in the appropriate Icarus command file. For a test requiring real DPI, load its bundle with the matching `vvp -d <bundle>`; see [UVM/DPI usage](../../uvm.md). These settings do not establish a full Caliptra DV pass. |

Current qualification and unresolved compiler blockers are in
[CURRENT_WORK](../CURRENT_WORK.md) and [BLOCKERS](../BLOCKERS.md). No source
overlay is an acceptable substitute for a missing compiler semantic fix.
