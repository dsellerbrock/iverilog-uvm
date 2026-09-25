# Current evidence and work

The selected 52 Caliptra L0 cases run on Icarus with explicit
`-gcommercial-unsafe` as the main **nonstandard compatibility** lane. A pass
still requires the intended marker, zero fail/error/assertion diagnostics,
and meaningful firmware execution. Strict mode supplies focused IEEE
mixed-driver rejection controls; its full-top compile failure is baseline
evidence. Named Caliptra and OpenTitan patches and options are selected per
test on disposable copies under the [release overlay guide](release_overlays/README.md),
leaving pinned source checkouts unchanged.

On the final private OpenTitan Icarus image recorded in the [OTP cover-bin
endpoint replay](../../evidence/opentitan-otp-cover-bin-method-20260925/README.md),
the pinned `otp_ctrl_smoke_vseq` completes **1/1 released nonstandard
compatibility DV** with six previously dropped coverage bins retained,
1343 checked TL A/D pairs, and zero UVM or assertion failures. The same
image separately recompiles and passes pinned `csrng_smoke_vseq` **1/1
nonstandard compatibility DV** with checked app-2 instantiate/generate/
uninstantiate traffic. These are two named tests, not a full OpenTitan
suite rate. OTP's after-alert bin hits and fault-injection `force` branches
are not qualified by this seed; CSRNG's ignored `int_state_read_enable_c`
item remains separate. Strict OTP compilation rejects 36 unproven nested
receiver endpoints and has no released runtime. The paired strict reducer,
UVM regression, and released-DV denominators are distinct.

On the `e75f26091` main baseline with local candidate changes, the
[fresh Icarus application DV census](../../evidence/icarus-dv-baseline-20260923/README.md)
records **0/52 strict Caliptra L0 runtimes attempted**: the [integrated PIC
strict top compile](../../evidence/caliptra-icarus-l0-strict-pic-nullguard-20260924/summary.json)
exits 46 on 46 mixed interface-member variable-driver errors, with zero
Preponed sampling warnings and the release's internal-TRNG define. The opt-in `-gcommercial-unsafe`
candidate compiled the pre-PIC top only after proving each overlapping task writer
unused for its concrete interface instance; called and uncertain writers
still fail. The [pre-PIC exact native-vector first compatibility
runtime](../../evidence/caliptra-icarus-l0-unsafe-final-first-20260924/smoke_test_veer/result.json)
was **0/1 attempted**, with 51 unrun, simulation exit 1, zero pass/fail
markers, 17,467 bad diagnostics and 621 instruction-trace entries. Its
reported retired-instruction and cycle counters are zero because no final
CSR dump was reached. Original TLU, SOC IFC and LSU assertions act at
43.865 us, and compile emitted zero Preponed sampling warnings. This remains
historical nonstandard compatibility evidence. The [integrated PIC focus](../../evidence/caliptra-pic-integrated-focus-20260924.log)
passes 4/4 paired cases. Its [initial exact unsafe first-case compile](../../evidence/caliptra-icarus-l0-unsafe-pic-first-20260924/summary.json)
crashed exit 139 on a null `Nexus::first_nlink()` in the new cprop reachability
traversal; an integrated null guard now lets the exact top compile to VVP. The
[completed exact first-case replay](../../evidence/caliptra-icarus-l0-unsafe-pic-nullguard-first-20260924/smoke_test_veer/result.json)
is nonstandard compatibility **0/1** with 51 unrun. Firmware and simulation
exit 0 with one pass marker, zero fail markers, 633 retired instructions,
4,348 cycles, and 634 trace commits, but 17,863 bad diagnostics fail the
unchanged zero-error gate. The former terminal 43.865 us SOC/TLU/LSU fatal
is absent, a runtime advance without an L0 pass. PIC source work is
suspended for error-root review after the P1 broad legacy, JSON, and REAL DPI UVM gates passed.

On the later installed P1 compiler (`ivl` SHA-256
`6ec92c4825dc51e3810d1cb22405071f033015626d39cf3db92c319aeb9d3b10`),
the [shared paired virtual-dispatch focus](../../evidence/caliptra-unsafe-virtual-dispatch-20260924/shared_focus.json)
passes 28/28. Its [strict full-top guard](../../evidence/caliptra-icarus-l0-strict-p1-20260924/README.md)
still exits 46 on exactly 46 genuine mixed-driver errors, with zero other
errors or Preponed warnings and no L0 runtime. The [P1-install broad legacy gate](../../evidence/caliptra-virtual-final-ivtest-gate-20260924.log) passes with 6,555 total, 6,550 ordinary passes, zero failures, two not implemented, and three expected failures; bundled VPI 131/131, negatives 155/155, and invariants 15/15 also pass. The [final REAL DPI UVM gate](../../evidence/caliptra-virtual-final-real-dpi-uvm-20260924.log) loads REAL DPI and passes 358/358 with both VIF smokes. The [P1-install full JSON compiler/VVP gate](../../evidence/caliptra-virtual-final-json-gate-20260924.log) passes 3,536/3,536 with zero failures; pristine compatibility review remains; [PR #350](https://github.com/dsellerbrock/iverilog-uvm/pull/350) is open.
The completed [bundled-BFM reset-copy diagnostic](../../evidence/caliptra-icarus-l0-diagnostic-reset-vif-20260924/README.md)
is separately **0/1** with 51 unrun: firmware and simulation exit zero,
one pass marker, 633 retired instructions, no startup errors, and exactly
17,844 vacuous KV/MLDSA checker messages as its only bad diagnostics. A
[six-nanosecond passive trace](../../evidence/caliptra-l0-timezero-passive-vpi-20260924/README.md)
records unknown reset-dependent checker inputs before the first clock
without assigning simulator or testbench causality. Pins and tool
fingerprints remain clean. The zero-error gate rejects the reset-copy case;
its diagnostic denominator stays separate from pristine unsafe
compatibility. The frozen [four-helper checker patch and paired controls](../../evidence/caliptra-l0-checker-source-overlay-20260924/README.md)
pass 4/4 paired 2017/2023 combinations, and the opt-in top compile exits
zero with zero sampling warnings. The [combined reset/checker disposable-copy first case](../../evidence/caliptra-icarus-l0-diagnostic-combined-p1-20260924/README.md) passes diagnostic qualification **1/1** with 51 unrun, zero bad diagnostics, one pass marker, 633 retired instructions, 4,348 cycles, and 634 trace commits. Pristine unsafe remains **0/1**; this diagnostic result is neither an IEEE nor a pristine L0 pass. The preliminary sequential `--all` diagnostic run was intentionally stopped during `smoke_test_mbox` after `smoke_test_veer` printed PASS. Its preserved partial output at `evidence/caliptra-icarus-l0-diagnostic-combined-all-p1-20260924/` is unqualified and has no aggregate verdict. The [during/after provenance record](../../evidence/caliptra-l0-active-sweep-provenance-20260924/README.md) confirms both copied firmware trees match 5,139 pinned non-Git entries except each case's named patch, and the xPack GCC 15.2 toolchain hashes stayed unchanged. Pinned sources remain clean.

A focused [ephemeral JTAG port check](../../evidence/caliptra-icarus-l0-runner-20260923/check_ephemeral_jtag_port.py) passes for a hash-guarded disposable copy of only the pinned top testbench: its sole `ListenPort` changes from `63224` to `0`, and JTAG server/bind errors fail the runner even with a pass marker. The opt-in `--commercial-unsafe --reset-overlay --checker-source-overlay --ephemeral-jtag-port` profile has qualification `diagnostic_reset_checker_source_ephemeral_jtag_port_overlay`. The [same-profile first case](../../evidence/caliptra-icarus-l0-ephemeral-jtag-first-20260924/README.md) passes separate diagnostic qualification **1/1** with 51 unrun, firmware/VVP exits zero, one pass marker, zero bad/DPI/JTAG diagnostics, 633 retired instructions, 4,348 cycles, and 634 trace commits; source/tool integrity matches. The [bounded four-job exact 52-case wrapper](../../evidence/caliptra-icarus-l0-parallel-runner-20260924/README.md) was deliberately SIGTERM-stopped after one completed `smoke_test_veer` PASS; its partial output at `evidence/caliptra-icarus-l0-patched-52-20260924/` is unqualified, with no aggregate result or orphan VVP. Longer first-cohort cases were still in released CRT `.data` copy loops: static map/disassembly shows about 17,700-17,900 instructions to `main` versus about 2,400 after 22 minutes, making the 1,800-second limit insufficient. A same-profile `smoke_test_mbox` pilot with `--timeout 14400` is active at `evidence/caliptra-icarus-l0-mbox-long-pilot-20260924/`. There is no 52-case aggregate result, pristine unsafe pass, or IEEE pass from this checkpoint.

An Icarus interface-port initialization fix cleared the initial null virtual interface, and native
vector generators now stage successfully. A hash-guarded reset-timing copy
probes a startup race; passive evidence does not yet assign simulator-versus-testbench cause. A
[paired AES reducer and fix](../../evidence/caliptra-aes-sensitivity-fix-20260923/README.md)
clear its subsequent time-zero sensitivity stall in both editions. The fresh
[copied-reset first case](../../evidence/caliptra-icarus-l0-diagnostic-aesfix-first-20260923/summary.json)
reaches 43.865 us and 621 instruction-trace entries, then fails a pinned
`soc_ifc_reg` known-input assertion alongside a Veer store-buffer assertion;
it is **0/1** with no L0 pass marker. A hash-guarded copied-source probe
finds an unknown PIC interrupt input before the terminal failures. A paired
2017/2023 reducer of the pinned PIC priority tree yields Z from 32 known-zero
leaves, proving an isolated Icarus defect. The suspended PIC lane has a
[narrow cprop.cc root cause](BLOCKERS.md#caliptra-pic-packed-partial-driver-cycle--dependent-packed-partial-drivers-form-a-self-cycle)
and paired passing controls; the completed first case no longer reaches the
former terminal fatal, but its remaining error roots and full causal chain
are unproved. Repeated MLDSA/KV checker messages
are [eager consequent side effects](../../evidence/caliptra-post-aes-sva-triage-20260923/README.md)
under false property antecedents in a paired reducer; they still disqualify
the pre-PIC runtime under the zero-error rule. Strict 2017/2023 mode continues
rejecting the driver overlap.
The separate bounded Caliptra/Adams Bridge unit subset has two checked
runtime passes and one checked failure; 20/44 unit filelists compile, which
is not a DV pass count. The OpenTitan 84-row matrix has zero clean rows:
eight runtime rows finish with pass banners but retain setup/compile debt,
while the others fail compilation, fail runtime, or time out. Its rows are
not all named tests or seeds. The former 51/52 Caliptra result below used
Verilator and is not Icarus progress.
In a separate [fresh named OpenTitan smoke subset](../../evidence/opentitan-named-smokes-20260923/README.md),
xbar and pwrmgr both pass with checked scoreboard traffic (2/2 attempted);
pwrmgr uses its documented disposable checker overlay. Only xbar (1/1)
qualifies as an unmodified-source smoke in that subset. Both named images
also pass a runtime-only replay under installed VVP `e9b7a64a` with the
same scoreboard traffic; the 84-row matrix has not been rerun under that
binary.

The [paired guarded joint-`dist` candidate](session_logs/2026-09-23_joint_proven_guard_focus.json)
passes 22/22 focused legacy and JSON checks. The earlier post-AES local
gates passed 6,508 ordinary legacy cases plus two not-implemented and three
expected-fail cases, 131/131 VPI, 155/155 negative, 15/15 runtime,
3,442/3,442 JSON, and 358/358 real-DPI UVM. The pre-PIC [full legacy
gate](../../evidence/caliptra-final-ivtest-gate-20260924.log) passes 6,551
total: 6,546 ordinary passes, zero failures, two not implemented and three
expected failures. Bundled VPI 131/131, negatives 155/155, and VVP invariants
15/15 also pass. Pre-PIC [JSON gate](../../evidence/caliptra-final-json-gate-20260924.log) passes 3480/3480. The pre-PIC [real-DPI UVM gate](../../evidence/caliptra-final-real-dpi-uvm-20260924.log) loaded DPI but failed with 356 passes and two compile failures: `vif_smoke` and `vif_smoke_v2` each report `count` mixed drivers at line 96. The disjoint VIF property-writer false overlap received a narrow elaborate.cc repair. The shared installed candidate passes [20/20 paired dedicated cases](../../evidence/caliptra-vif-disjoint-property-writer-20260924/shared_new_focus.log) and [16/16 neighboring controls](../../evidence/caliptra-vif-disjoint-property-writer-20260924/shared_neighbor_focus.log); both VIF smokes privately compiled/ran under real DPI with `PASS counter_test` and zero UVM error/fatal. Installed iverilog/ivl/vvp SHA-256 prefixes are 1590b064/ba1dda3d/e9b7a64a. The [full shared real-DPI UVM umbrella](../../evidence/caliptra-vif-final-real-dpi-uvm-20260924.log) now passes 358/358 with zero failures/skips and both VIF smokes passing. This clean UVM regression gate is separate from Caliptra L0. The [fresh VIF-install exact unsafe first case](../../evidence/caliptra-icarus-l0-unsafe-vif-first-20260924/README.md) fails nonstandard compatibility 0/1 with 51 unrun and 17,863 diagnostics despite a pass marker and 633 retired instructions. The first [VIF-install broad legacy gate](../../evidence/caliptra-vif-final-ivtest-gate-20260924.log) failed one `sv_packed_mixed_driver_compound` expected-warning gold mismatch (6,555 total; 6,549 pass; two not implemented; three expected failures); its corrected gold passes focused legacy 1/1 and JSON 2/2. The broad rerun was intentionally stopped when independent review found a P1 unsafe virtual-dispatch called-task false waiver. A [private P1 candidate](../../evidence/caliptra-unsafe-virtual-dispatch-20260924/README.md) passed 28/28 dedicated and 34/34 neighboring controls; the installed [shared paired focus](../../evidence/caliptra-unsafe-virtual-dispatch-20260924/shared_focus.json) now passes 28/28. The P1-install broad legacy and REAL DPI UVM gates pass, as does [full JSON](../../evidence/caliptra-virtual-final-json-gate-20260924.log) 3,536/3,536; pristine compatibility review remains; [PR #350](https://github.com/dsellerbrock/iverilog-uvm/pull/350) is open. [BLOCKERS](BLOCKERS.md) records the selected narrow elaborate.cc repair. Required broader PIC qualification and error-root triage remain pending. A paired self-proof reducer
exposed and repaired an unsafe success caused by a random-dependent
distribution weight.
The pinned OpenTitan CSRNG replay still raises `UVM_FATAL` on a distinct
unresolved random guard, so it is not a DV pass. The AES focus passes 8/8
paired cases. On the pre-PIC shared install, driver focus passes 34/34,
interface-port/ref focus 28/28, and nested constant packed-select Preponed
focus 2/2 in each legacy and JSON harness. The full top has zero Preponed
sampling warnings; dynamic nested-index sampling remains unqualified. The VIF property-writer repair passes paired focus and the earlier real-DPI UVM recheck 358/358. The P1 unsafe virtual-dispatch repair now passes installed paired focus 28/28; the first broad legacy gate failed one expected-warning gold mismatch and its rerun was intentionally stopped before P1 installation. The P1-install broad legacy, full JSON 3,536/3,536, and REAL DPI UVM gates pass; pristine compatibility review, PIC error-root review, and publication remain open.

[PR346](https://github.com/dsellerbrock/iverilog-uvm/pull/346) merged after
exact-head CI success. The later CSRNG parser, solver, pinned-release overlay,
VVP loader, exact coupled distribution, and time-zero scheduler fixes are
merged in [PR348](https://github.com/dsellerbrock/iverilog-uvm/pull/348) at
`398bf5c65`. The latest
[SPI solver evidence](../../evidence/opentitan-spi-lazy-item-20260923/result.json)
records a bounded runtime stall after UVM startup. The
[CSRNG scheduler evidence](../../evidence/opentitan-csrng-timezero-scheduler-20260923/result.json)
records a repaired pre-start stall and a separate UVM_FATAL at
`cfg.randomize()`; the [paired guarded-`dist` reducer](../../evidence/opentitan-csrng-cfg-joint-dist-20260923/README.md)
isolates the next solver restriction. Neither is a DV pass. The
[post-load CSRNG reducer](../../evidence/opentitan-csrng-post-load-triage-20260923/README.md)
and [pinned overlay guide](release_overlays/README.md) bound those attempts.
The earlier [revision-scoped record](session_logs/2026-09-23_opentitan_spi_csrng_next.json)
preserves the preceding `df9f167f4` observations; it is not current
qualification. A [post-scheduler AON runtime replay](../../evidence/opentitan-aon-merged-scheduler-20260923/result.json)
passes using the earlier pinned image and current installed VVP; it is one
selected smoke, not a fresh compile or full DV. Full OpenTitan DV remains open.
The [merged-branch legacy gate](../../evidence/ivtest-broad-gate-20260923/merged-gate-result.json)
and [full JSON VVP regression](../../evidence/ivtest-broad-gate-20260923/merged-json-result.json)
pass after focused test-oracle repairs: 6,458 legacy tests with no unexplained
failures, 131/131 VPI, 155/155 negative, and 3,388/3,388 JSON. The real-DPI
UVM umbrella passed 358/358 on the pre-merge candidate; it still requires
exact-head CI confirmation for the combined branch.

The preceding focused integration was at `0a902ee9f`, following constant
unpacked-array membership support at `88f0e9044`. Its revision-scoped
[session record](session_logs/2026-09-23_inside_array_named_event_integration.json)
owns that earlier paired test and application observation. The pinned SPI Device
compile then had three kind-26 errors: two queue array-concatenation sites and
one constraint-context `inside` site. The released AON compile had zero errors,
but its smoke run timed out at 60 seconds after a `$system` warning. These are
focused compile/runtime observations, not OpenTitan DV qualification. Raw
[SPI compile](../../evidence/opentitan-spi-aon-focus-20260923/spi-device-compile.log),
[AON compile](../../evidence/opentitan-spi-aon-focus-20260923/aon-timer-compile.log),
the [AON timeout](../../evidence/opentitan-spi-aon-focus-20260923/aon-timer-smoke-timeout.log),
and a [bounded AON time trace](../../evidence/opentitan-spi-aon-focus-20260923/aon-timer-time-trace.log)
are retained. The traced run reached 416009004 ps before timing out, so the
timeout does not indicate a zero-time spin; neither earlier bounded run
produced a UVM verdict.

The preceding [scope `std::randomize` queue record](session_logs/2026-09-23_scope_queue_randomize_focus.json)
is now integrated in this tree; it covers one-dimensional local integral
queues with exactly constrained lengths through 65536 elements, including
declared maxima. Earlier reports of eight later vector-context diagnostics
are superseded by the current pinned SPI replay recorded above.

The preceding [associative statement-method focus](session_logs/2026-09-23_assoc_queue_statement_methods_focus.json)
is on `d0560368e`; its follow-on PR, broad gates, and application DV qualification remain
open. The [OpenTitan `find_index` and multi-object event record](session_logs/2026-09-23_opentitan_assoc_find_index_multi_object_focus.json)
merged in [PR341](https://github.com/dsellerbrock/iverilog-uvm/pull/341) at
`7943dffd1` after exact-head Ubuntu 24.04 success. PR340 merged at `909e3f314`
after exact-head Ubuntu 22.04 success; its [class-event `.triggered` record](session_logs/2026-09-23_opentitan_class_event_triggered_focus.json)
preserves the scoped evidence. The PR341 UCRT64 checkout stopped at certificate
trust before invoking the compiler.

The [PR339 compiler and VPI repair record](session_logs/2026-09-23_spi_adc_pr339_repair_focus.json)
links the package-parameter `foreach`, packed-struct queue `.size`, direct
unbased-fill cast, caller-queue, and VPI callback corrections to local gates
and a fresh pinned SPI Device compile. PR339 merged at `6fd804a39` after its
Ubuntu 24.04 exact-head check passed; SPI Device, ADC, and full application DV
remain unqualified.

The [parallel compiler follow-on record](session_logs/2026-09-23_parallel_compiler_followon_focus.json)
links locally integrated ADC outer resize, SPI Device sparse-key constraint
`foreach`, and VPI force/release statement-object checks on the branch after
[PR338](https://github.com/dsellerbrock/iverilog-uvm/pull/338) merged. Indexed
ADC inner sizes, full SPI Device DV, broad suites, and this branch's CI remain
open.

The [latest pinned Caliptra L0 replay](../../evidence/caliptra-l0-52-and-full-dv-gap-20260923/full_l0_summary.json)
records 51/52 selected passes with the two test-specific firmware overlays;
DOE scan alone remains failed on an intact assertion. The earlier
[exact-toolchain baseline](../../evidence/caliptra-exact-l0-20260923/README.md)
was 49/52. A [single CSRNG unit runtime](../../evidence/caliptra-csrng-unit-runtime-20260923/README.md)
passes its explicit checks after a disposable filelist-order and include-path
correction, while emitting unique-case warnings; the full DV suite remains
unqualified.

The [DOE passive timing trace](../../evidence/caliptra-doe-root-cause-20260923/assessment.md)
confirms that Verilator retains a pre-reset `|=>` attempt that IEEE `disable iff`
requires it to abort; no fresh post-reset antecedent was sampled. The earlier
[source diagnosis and restored Verilator recheck](session_logs/2026-09-23_caliptra_doe_verilator_defuture_blocker.json)
identify the defutured implication mechanism. The intact DOE test remains a
strict L0 failure until a corrected simulator passes it without SVA errors.

The [Caliptra KV SVA diagnostic overlay replay](session_logs/2026-09-23_caliptra_kv_sva_overlay_l0.json)
is scoped to pinned Caliptra `v2.1.2` and Verilator. It removes false-antecedent
inner diagnostics while retaining detailed failure output; this is diagnostic
evidence with a RISC-V multilib caveat, not full L0 or Caliptra DV qualification.

The [ADC guarded-distribution and OpenTitan fileset record](session_logs/2026-09-23_opentitan_adc_guarded_dist_fileset_focus.json)
is scoped to solver and matrix commits `4e14d8dde`/`e94e25e37`. The focused
checks preceded their rebase onto merged PR336; relevant source and tests are
byte-identical after the rebase. The guarded large-range `dist` correction
passes paired 2017/2023 focused checks (4+4) and neighboring distribution
checks (36+36). The pinned ADC smoke now gets past the exact-distribution
resolver but still fails at time 0 because global randomization cannot resize
its nested dynamic array; this is not a DV pass. The matrix runner now
selects generated RTL filesets, and focused pinmux setup compiles. The full
OpenTitan matrix was not rerun.

The [case-exit stack balance record](session_logs/2026-09-23_pwrmgr_case_exit_stack_balance.json)
links the focused compiler checks to the pinned released OpenTitan pwrmgr replay:
all named pwrmgr tests at seed 1 and smoke seeds 1–6 retain matched TL scoreboard
traffic, with the earlier cleanup diagnostics removed. This is a frozen
generated-source snapshot with the documented checker overlay and remaining
compile warnings, not the full release DV suite. A fresh full OpenTitan and
Caliptra DV inventory and failure census are active separately.

The [integrated focus record](session_logs/2026-09-23_vpi_macro_integrated_focus.json) covers the matched-bracket macro correction and VPI variable-bit force/release callback rejection merged in [PR335](https://github.com/dsellerbrock/iverilog-uvm/pull/335). Paired and neighboring tests pass; Ubuntu 24.04 exact-head CI succeeded after the merge. The [macro baseline](../../evidence/macro-bracket-assessment-20260923/README.md) preserves the original failures.

The [Caliptra long-sequence register fix](session_logs/2026-09-23_caliptra_long_sequence_register_focus.json) at `4ff0581df` passed executable and neighboring checks before integration. On the [locally integrated tree](session_logs/2026-09-23_caliptra_pm_integrated_compile.json), the clean pinned PM formal filelist compiles without diagnostics in both editions and the long-sequence focus passes. The fix merged in [PR335](https://github.com/dsellerbrock/iverilog-uvm/pull/335); this is formal-file compile evidence only, with full DV and formal proof still open.

The [Caliptra late-default-clocking record](session_logs/2026-09-23_caliptra_late_default_clocking_focus.json) covers paired 2017/2023 checker execution and rejection boundaries on source/test commit `342226068`; the pinned clean ECC formal compile moves past five false clock diagnostics but still fails at a separate `DSA_NOP` binding error. A [one-token, test-specific released-source overlay](session_logs/2026-09-23_caliptra_ecc_nop_overlay.json) makes that filelist compile in a disposable copy; no formal proof or DV runtime is claimed. [PR334](https://github.com/dsellerbrock/iverilog-uvm/pull/334) merged after Ubuntu 24.04 exact-head CI passed.

The [pinned OpenTitan ADC macro-argument baseline](session_logs/2026-09-23_opentitan_adc_macro_arg_baseline.json) isolates the first `adc_ctrl_sim` compile error to `ivlpp` scanner nesting around a cast. The [focused candidate](session_logs/2026-09-23_opentitan_adc_macro_arg_focus.json) compiles the same generated release source list on source/test commit `284a4c65d`, but an ignored filter-size constraint and a separate cast-width runtime defect prevent a semantic compile or DV-pass claim. No ADC smoke ran.

The [named-antecedent Caliptra ECC record](session_logs/2026-09-23_caliptra_named_sequence_antecedent.json) covers a one-step declared sequence ahead of an instance-sized symbolic consequent. Paired 2017/2023 executable checks and the pinned full ECC formal bind compile passed locally on `312eff1af`; this subset merged in [PR333](https://github.com/dsellerbrock/iverilog-uvm/pull/333) after an exact-head CI success. Multi-step antecedents and full Caliptra DV/formal qualification remain open.

The [fixed SVA overlap and VPI attempt-identity record](session_logs/2026-09-23_sva_literal_overlap_attempt_identity.json) covers separate same-edge failure verdicts, four-state nonmatches, and exact callback start times in the fixed linear checker. Paired-edition reducers and required local gates passed on `e54b76124`; this subset merged in [PR332](https://github.com/dsellerbrock/iverilog-uvm/pull/332) after an exact-head CI success. Window, unbounded, and negated checker metadata, full SVA, and application DV remain separate.

The [Caliptra consequent-repetition candidate](session_logs/2026-09-23_caliptra_param_consequent_repeat_focus.json) records paired-edition executable assertion checks and a pinned formal-file compile with no dropped repeat properties; the [baseline](session_logs/2026-09-23_caliptra_param_consequent_repeat_baseline.json) preserves the original failure. It passed its required local gates and merged in [PR330](https://github.com/dsellerbrock/iverilog-uvm/pull/330) after exact-head CI success, following [PR329](https://github.com/dsellerbrock/iverilog-uvm/pull/329). The standalone bind-target error and full Caliptra DV/formal qualification remain separate.

The [released pwrmgr replay](session_logs/2026-09-23_pwrmgr_release_overlay_current.json) records seed-1 and seed-3 smoke passes with observed TL traffic on a frozen pinned-release source snapshot and the checker overlay. The [release profile](release_overlays/README.md) names the required compiler-command-file timescale; this documentation correction merged in [PR331](https://github.com/dsellerbrock/iverilog-uvm/pull/331). It does not establish full OpenTitan DV qualification.

The [class-property queue-pop candidate](session_logs/2026-09-23_opentitan_queue_pop_focus.json) at `a0e45a3c7` has passing paired focused tests and a pinned SPI Host compile with no queue-pop drop. A [review boundary follow-up](session_logs/2026-09-23_queue_pop_assoc_boundary.json) at `3b6d1986f` rejects queue-only pops on associative arrays in expression context while preserving queues stored inside them. This subset merged in [PR329](https://github.com/dsellerbrock/iverilog-uvm/pull/329). [Statement-context calls remain incorrectly accepted](session_logs/2026-09-23_assoc_queue_pop_statement_debt.json) and are tracked separately. Four unresolved constraint-index warnings still prevent a semantic SPI compile or DV-pass claim.

The earlier [OpenTitan selected-bit NBA and task-error candidate](session_logs/2026-09-23_opentitan_nba_codegen_focus.json) merged in [PR328](https://github.com/dsellerbrock/iverilog-uvm/pull/328) at `4f66ed666`. Its local validation and earlier SPI compile remain scoped to that source. Four unresolved constraint indices and a later queue-pop candidate still delimit the SPI result; the correctly configured fixed-seed smoke passed the earlier time-zero regex barrier and aborted on a VIF event-relay runtime form at 3,673,793 ps. The target-specific [release overlay profiles](release_overlays/README.md) define the pinned application sources, patch selection, and observed run options.

The opt-in `-gcommercial-unsafe` mode merged in [PR326](https://github.com/dsellerbrock/iverilog-uvm/pull/326) at `fa5ae6da5` (source commit `9111127532c71fc4eeaf1bab68685ade3c61296f`). Its [focused flag checks](session_logs/2026-09-23_commercial_unsafe_flag.json) and [post-merge local qualification](session_logs/2026-09-23_pr326_postmerge_qualification.json) are separate records: the latter passed the required compiler/ivtest/SVA and real-DPI UVM gates on a compiler/test tree identical to merged `main`; CI was pending at observation. The flag alone cleared strict SPI type errors but left the selected-bit NBA target errors later addressed by the current candidate. OpenTitan DV has not passed.

The [Caliptra `rej_bounded` race fix](session_logs/2026-09-23_caliptra_rej_bounded_race_fix.json) has a separately tested, minimal [Adams Bridge testbench patch](repros/caliptra_rej_bounded/README.md), now proposed in [upstream PR 303](https://github.com/chipsalliance/adams-bridge/pull/303). The pinned releases remain unmodified and failing; the patched-copy result is focused application evidence, not full Caliptra DV qualification.

The earlier [scalar caller-state X/Z port](session_logs/2026-09-23_constraint_state_xz_port.json) passed its required local runtime gates on source/test commit `527c0930a` and merged in [PR325](https://github.com/dsellerbrock/iverilog-uvm/pull/325) at `7044ae62c` after Ubuntu 22.04 CI passed. The known wide caller-state truncation is recorded in [DISCOVERED_DEBT](DISCOVERED_DEBT.md); it is not part of the X/Z scope.

The [branch reconciliation](session_logs/2026-09-23_pr322_branch_reconciliation.json) records that PR322 closed without a merge while its independent fixes were committed directly to `main`. The missing fixed-array element guard and caller-boundary regressions merged in [PR324](https://github.com/dsellerbrock/iverilog-uvm/pull/324) at `ea0be16d5`; its [exact-source local qualification](session_logs/2026-09-23_pr322_reconciliation.json) is preserved, while PR324 CI was still running at this checkpoint. PR323's guarded inline-function path covers the caller-method tests, and PR322's bypassing shortcut was removed. That checkpoint still had queue-element type errors and no SPI DV pass; the newer flag result is linked above.

The earlier [inline constraint state-function candidate](session_logs/2026-09-23_inline_state_function_focus.json) records the state-only scope now merged in PR323. Random-variable actual arguments and wide results remain open. The [MSYS2 strict-regex fix](session_logs/2026-09-22_win_regex_tre_fix.json) merged in PR321; its prior pending-CI note is historical.

The [caller-owned queue foreach candidate](session_logs/2026-09-22_caller_queue_foreach_focus.json) records passing required local gates and removal of the corresponding pristine SPI compile error. It merged as PR320 (`1af223c8`); independent SPI errors remain.

The [until continuation candidate](session_logs/2026-09-21_until_continuation_focus.json) records the compiler correction and passing required local validation. It merged as [PR319](https://github.com/dsellerbrock/iverilog-uvm/pull/319) (`288132f2`); Ubuntu and macOS CI passed and all three MSYS2 jobs failed only `uvm_regex_strict_exec_test`. Broader assertion and application qualification remains open.

The [selected-VIF edge candidate](session_logs/2026-09-21_selected_vif_edge_focus.json) records the current compiler patch, passing required local gates and stable-release application replays. Merged in [PR318](https://github.com/dsellerbrock/iverilog-uvm/pull/318) as `ca29b1237` after both Ubuntu CI jobs passed; remaining platform checks were still running.

The [seed-3 upstream revalidation](session_logs/2026-09-21_pwrmgr_seed3_upstream_revalidation.json) confirms valid stimulus and an upstream checker defect, separately validates the minimal checker overlay, and records the stronger backport's uncovered `until` continuation gap. Patched results do not qualify the pristine release.

The [SPI class event-list checkpoint](session_logs/2026-09-21_spi_class_event_list_focus.json) records paired-edition semantic tests and mapped UVM validation. Pristine SPI Host still fails compilation; this is not application qualification.

The [current-build seed-3 recheck](session_logs/2026-09-21_pwrmgr_seed3_current_build_recheck.json) reconfirms the corrected checker passes and the pristine release fails, with unchanged corpus and recorded dirty compiler-patch provenance.

The [seed-3 checker correction](session_logs/2026-09-21_pwrmgr_seed3_checker_fix.json) records a separately patched upstream checker, passing seed1/seed3 smoke, and retained stopped-clock failure checks. The pristine release stays unchanged and its seed3 remains failing; this is patched-DV evidence.

The [pwrmgr seed-3 assessment](session_logs/2026-09-21_pwrmgr_seed3_phase_assessment.json) identifies a clock-phase assumption in the unchanged upstream assertion. The run remains failing; this is diagnostic evidence, not an application pass or a compiler fix.

Latest focused candidate: [whole-function class event expressions](session_logs/2026-09-21_whole_function_event_focus.json). Permanent harnesses and all required local gates pass; publication/CI remain pending. The merged compiler baseline is PR315 (`175dcb65d`), with [occurrence-time event qualification](session_logs/2026-09-21_occurrence_event_focus.json); earlier pending publication notes are superseded. Full application DV qualification remains open.

Fresh [unmodified stable-release replays on this candidate](session_logs/2026-09-21_whole_function_event_applications.json) preserve the known passing and failing cases; compiler qualification remains pending.

Latest compiler qualification: [PR312 required local gates](session_logs/2026-09-21_pr312_local_qualification.json) pass on repair source `0b1aeaee6`, identical to `b5bc2864f` for compiler/test inputs. CI remains pending. This supersedes pending local-gate statements below; application outcomes retain their recorded provenance.

Latest PR309 evidence: [required local qualification](session_logs/2026-09-21_pr309_local_qualification.json) passes on `09316da3d`; PR309 merged as `cb6f35b56` while CI was still running. This supersedes the earlier pending-local-gate notes below without changing their historical results or claiming full application qualification.

Documentation checkpoint: **2026-09-14**, reviewed against `main` revision
`9c8f716b1`; operational handoff reconciled after documentation merge
`fdbb8f34a` and local sync `3ab991187`. This page points to recorded evidence; it does not claim a fresh
run on every later checkout.

## September 20 merged-baseline restoration

The [restoration record](session_logs/2026-09-20_merged_baseline_restoration.md)
identifies source/test changes missing after the three PR merges and the
reviewed checkpoint used to restore them. The local qualification is linked below.

## September 20 integration review

The [PR review and repair record](session_logs/2026-09-20_pr_review_repairs.md)
identifies the three reproduced defects and their repairs. PR306 restored
the reviewed compiler/test tree to main. Resumption and
validation state belong to ACTIVE_WORK and CAMPAIGN linked below.

## Latest merged baseline

[PR308 merge record](session_logs/2026-09-21_pr308_merge.json): main is `482c3c89d`, with the nine-fix locally qualified batch merged after both Ubuntu CI jobs passed. Four other jobs were still running at observation. The [PR307 record](session_logs/2026-09-21_pr307_merge.json) retains the preceding baseline.

## Current focused implementation

The [port regression repair](session_logs/2026-09-21_port_regression_repair.json) removes the unnecessary behavioral carrier and preserves structural propagation. Shared qualification remains pending the event repairs.

The [six-fix installed focus](session_logs/2026-09-21_shared_six_focus.json) records the shared rebuild and passing permanent regressions. The [broad gate failed](session_logs/2026-09-21_shared_six_gate_failure.json), so qualification is pending repair. The [fresh stable-release replay](session_logs/2026-09-21_shared_six_release_retest.json) records current application results.

The [variable-output review](session_logs/2026-09-21_variable_output_integration_review.json) records private semantic and integration checks; shared qualification is pending.

The [Caliptra boundary trace](session_logs/2026-09-21_caliptra_rej_boundary_trace.json) records evidence for the remaining testbench scheduling race; the test still fails.

The [private Caliptra string replay](session_logs/2026-09-21_caliptra_string_private_replay.json) records progress past filename/vector generation and the remaining scoreboard failure. It is candidate evidence, not an integrated application pass. The [synthesis review](session_logs/2026-09-21_caliptra_string_synthesis_review.json) records the corrected candidate and its replay.

The [scope solver UNKNOWN repair](session_logs/2026-09-21_scope_solver_unknown_fix.json) is focused-tested on the next-batch branch. The [long fixed antecedent repair](session_logs/2026-09-21_long_fixed_antecedent_fix.json) is also focused-tested. Broad next-batch qualification is pending; both fixes are separate from PR307.

The [constraint object-method repair](session_logs/2026-09-21_constraint_object_method_receiver.json) has paired focused and neighboring regression evidence; broad batch gates remain pending.

The [bare enum-name repair](session_logs/2026-09-21_enum_bare_name_type.json) has paired focused and enum-neighbor evidence, pending broad batch gates.

The [self-package cast repair](session_logs/2026-09-21_self_package_type_cast.json) and [signed coverage range repair](session_logs/2026-09-21_signed_cover_range_resolution.json) have paired focused evidence. Required broad batch gates remain pending.

The [pwrmgr startup replay](session_logs/2026-09-21_pwrmgr_startup.json) reaches runtime but fails HDL-path checking; compiler fallback warnings also exclude application qualification.

The [nine-fix checkpoint release retest](session_logs/2026-09-21_batch_nine_release_retest.json) records fresh stable-source application results and the current broad-gate failure. Full batch qualification remains pending.

## Latest recorded compiler qualification

The [nine-fix batch qualification](session_logs/2026-09-21_nine_fix_batch_qualification.json) records all seven required local gates passing on semantic revision `c1635efe9`, including the synthesis metadata repair. CI, private next-batch candidates, and full application/standards qualification remain separate.

The [next-candidate release retest](session_logs/2026-09-21_next_candidate_release_retest.json) preserves earlier bounded OpenTitan and Caliptra runtime results, including source/binary fingerprints and clean release pins. It does not qualify the pending compiler patches. The [published-candidate retest](session_logs/2026-09-21_published_candidate_release_retest.json) and September 20 static census remain revision-scoped historical evidence.

The [canonical graph and cleanup record](session_logs/2026-09-21_canonical_graph_cleanup.json) records the restored main checkout, shared graph refresh, retired worktree, preserved branch, and cleanup audit.

The [September 21 batch qualification](session_logs/2026-09-21_compiler_batch_qualification.json) records all seven local gates passing for semantic revision `8ab943352`. It supersedes the earlier batch checkpoints below for local compiler validation; GitHub CI and application revision limits remain separate.

The [restored-baseline qualification](session_logs/2026-09-20_restored_baseline_qualification.json)
records all seven local gates passing for semantic revision `e90059a07`,
whose compiler/test tree matches merged main `0998f058a`. Counts, commands,
artifact fingerprints and edition limits live in that record. GitHub CI
remains separate from this local evidence.

The earlier [L96–L105 qualification](session_logs/2026-09-15_compiler_batch_l96_l105_qualification.json)
and [batch session](session_logs/2026-09-15_compiler_batch_l96_l105.md)
retain their revision-scoped results.

This qualifies that local candidate, not full IEEE, UVM or whole-application
support. Earlier [L85–L95](session_logs/2026-09-15_compiler_batch_l85_l95_qualification.json),
[L75–L84](session_logs/2026-09-14_compiler_batch_l75_l84_qualification.json),
[L65–L74](session_logs/2026-09-14_compiler_batch_l65_l74_qualification.json)
and [L64](session_logs/2026-09-14_constraint_function_presolve_qualification.json)
records retain their original revisions and limits.

## Application evidence

The [type-first candidate release retest](session_logs/2026-09-21_typed_candidate_release_retest.json)
records the later candidate fingerprints, fresh unmodified release runtime results,
remaining GPIO failure, and cleanup disposition. This bounded run does not qualify
the pending compiler batch.

The [September 21 bounded release retest](session_logs/2026-09-21_stable_release_retest.json)
records fresh compiler/runtime fingerprints, unmodified Caliptra unit and OpenTitan
peripheral-crossbar results, GPIO failure, and cleanup. It covers the recorded
uncommitted candidate; it does not qualify the pending compiler batch.

The [September 20 stable-release replay checkpoint](session_logs/2026-09-20_stable_release_replay.json)
records the fresh Caliptra static census and unmodified power2round unit-runtime
pass with warnings, unmodified OpenTitan TL-agent and Earlgrey xbar UVM test
verdicts with a runtime warning, the completed census, and audited cleanup. These bounded
results do not establish full-chip or complete application qualification.

The [September 15 OpenTitan `xbar_smoke` UVM pass](session_logs/2026-09-15_opentitan_xbar_smoke_patched.md)
is the first UVM test to reach `TEST PASSED CHECKS` against a stable OpenTitan
release (Earlgrey-PROD-M6). **It is a patched-release result, not an
unmodified-source pass** — one `dv_report_catcher.sv` source correction was
required for a nonstandard `foreach` spelling (upstream syntax defect, not an
Icarus gap; see the log for the IEEE 1800 §12.7.3 citation). The original,
unmodified file's failure is preserved, not overwritten.

The [September 13 OpenTitan/Caliptra census](session_logs/2026-09-13_opentitan_caliptra_rebaseline_after277.md)
is scoped to `631bba6e8`. It predates L43–L64 and is not an application replay
of the newer compiler. It includes failures and dependency/configuration debt;
completion of the census is not application success.

The [UVM release matrix](uvm_release_matrix.md) owns library acquisition and
release-smoke interpretation. The [2017 clause matrix](matrices/ieee1800_2017_clause_matrix.md)
and [2023 survey](ieee1800_2023_delta.md) own standards dispositions.

## Work selection and resumption

- [BLOCKERS](BLOCKERS.md): operational backlog and blocker status.
- [ACTIVE_WORK](../../.ai/ACTIVE_WORK.yaml): selected implementation ticket.
- [CAMPAIGN](../../.ai/CAMPAIGN.yaml): operational handoff, exact next command,
  and pending work. Check its revision before resuming; it may lag committed
  qualification evidence.
- [DISCOVERED_DEBT](DISCOVERED_DEBT.md): observations awaiting triage.
- [AGENTS](../../AGENTS.md): workflow, toolchain, and validation requirements.

The campaign owner reconciled the handoff with the final L64 JSON linked above.
The earlier operational record is preserved in the
[handoff archive](session_logs/2026-09-14_campaign_handoff_archive.yaml).
L64 was published in [PR280](https://github.com/dsellerbrock/iverilog-uvm/pull/280)
and externally merged as `5c0f5588e`; this does not turn its local qualification
into cross-platform qualification.

[PR281](https://github.com/dsellerbrock/iverilog-uvm/pull/281), externally merged
as `9c8f716b1`, repairs build defects exposed by that publication. Its current revision, CI state, and exact next
command belong to CAMPAIGN. The post-L64 batch is locally qualified by the
latest record above. Publication status and subsequent work remain in CAMPAIGN.
No newer whole-application replay is claimed.

## History

The former continuation narrative is preserved in the
[July–September archive](session_logs/2026-09-14_current_work_archive.md).
Earlier checkpoints and failed attempts remain in the
[session logs](session_logs/README.md). Keep historical results revision-scoped;
update these pointers when new evidence is committed.

The [grouped clocked consequent record](session_logs/2026-09-20_grouped_clocked_consequent.md) provides focused paired-edition evidence pending the next batch qualification.

The [masked memory synthesis record](session_logs/2026-09-20_masked_memory_synthesis.json) contains the next paired focused checkpoint, pending batch qualification.

The [variable-row assignment record](session_logs/2026-09-20_variable_row_assignment.json) contains paired focused evidence and the remaining Ibex synthesis boundary.

The [state-selected constraint record](session_logs/2026-09-21_state_selected_fixed_array_constraints.json) tracks the next paired focused candidate and its validation status.

The [reset-only synthesis record](session_logs/2026-09-21_reset_only_synthesis.json) records the next paired runtime checkpoint.

The [restoration CI checkpoint](session_logs/2026-09-21_restoration_ci_checkpoint.json) records live exact-head platform status for PR306, independently of the current batch.

Latest bounded application retest: [queue-validity candidate release evidence](session_logs/2026-09-21_queue_candidate_release_retest.json). This does not supersede full compiler qualification.

The [constraint cast/distribution checkpoint](session_logs/2026-09-21_constraint_cast_distribution_checkpoint.json)
records focused and neighboring regression evidence for `969853350`, pending broad batch qualification.

The [September 21 candidate release retest and cleanup](session_logs/2026-09-21_candidate_release_retest_and_cleanup.json)
records fresh pinned-release application results and disposable binary removal.
It does not qualify the current uncommitted compiler candidate.

The [synthesis and wide-index focused checkpoint](session_logs/2026-09-21_synthesis_and_wide_index_focus.json) records paired-edition runtime and neighboring-test evidence. Required broad batch gates remain pending.

The [repaired-candidate release retest](session_logs/2026-09-21_repaired_candidate_release_retest.json) supersedes the earlier application snapshot for the latest elaboration repairs. Full batch qualification remains pending.

The [empty-branch enable repair](session_logs/2026-09-21_empty_branch_enable_repair.json) records the JSON-discovered synthesis regression and focused recovery; the final broad run is tracked in CAMPAIGN.

Latest bounded release replay: [2026-09-21 current candidate](session_logs/2026-09-21_current_release_retest.json). Exact pins, commands, runtime outcomes and qualification limits are recorded there.

Latest packed-VPI local checkpoint: [paired tests and affected-suite evidence](session_logs/2026-09-21_packed_vpi_integration.json). Broad batch qualification remains pending.

The [constraint divide/remainder error repair](session_logs/2026-09-21_constraint_divmod_zero.json) has paired focused and neighboring runtime evidence; broad batch gates remain pending.

The [joint ordered-randc repair](session_logs/2026-09-21_joint_ordered_randc.json) has paired runtime, distribution and rollback evidence; batch gates remain pending.

Latest bounded stable-application replay: [qualified nine-fix candidate](session_logs/2026-09-21_qualified_nine_release_retest.json). Exact corpus pins, binary fingerprints, commands, pass/failure evidence and scope limits are in that record.

Draft review checkpoint: [PR #309](https://github.com/dsellerbrock/iverilog-uvm/pull/309) publishes `b03bccdf9` for review. It is not a qualified baseline; the PR lists the preserved local regression failures and required repair/requalification. Current private repair lanes and the uncommitted automatic-context integration are recorded in `.ai/CAMPAIGN.yaml`.

[Event runtime repair checkpoint](session_logs/2026-09-21_event_runtime_regression_repair.json) supersedes the runtime failure status above for its recorded source/tools. Synthesis repairs and broad requalification remain pending; PR #309 stays draft.

[Synthesis event repair evidence](session_logs/2026-09-21_synthesis_event_regression_repair.json) records the successful replay of all earlier failing legacy/VPI cases and new paired boundary tests. [Fresh pinned release replay](session_logs/2026-09-21_repaired_release_replay.json) and [initial PR309 CI classification](session_logs/2026-09-21_pr309_initial_ci.json) preserve application limitations and the Windows export repair. Full repaired-revision gates are pending.

The [OpenTitan regex trace](session_logs/2026-09-21_opentitan_regex_attribution.json) attributes the current GPIO/pwrmgr startup errors to a direct glob-shaped argument reaching the strict legacy regex API. It establishes no application pass or new compiler fix.

The [OpenTitan crossbar expansion](session_logs/2026-09-21_opentitan_crossbar_expansion.json) records the upstream zero-delay variant pass and random-test timeout without workload reduction. It does not qualify the full suite.

The [PR309 CI checkpoint](session_logs/2026-09-21_pr309_ci_checkpoint.json) records Ubuntu 24.04 success on the merged compiler revision; remaining platforms were still running at capture.

Latest SPI Host compiler checkpoint: [fixed member-array constraint evidence](session_logs/2026-09-21_spi_host_member_array_focus.json). Required broader checks and application blockers remain explicit in the record.

The [OpenTitan configuration correction and replay](session_logs/2026-09-21_opentitan_regex_configuration.json) supersedes the earlier no-configuration-mismatch conclusion. Application qualification remains limited as recorded there.

[Dependency-kind regression repair](session_logs/2026-09-21_spi_host_dependency_kind_repair.json) records the broad-gate failures and focused recovery for PR311; broader requalification remains pending.

PR #311 merged externally before the dependency-kind repair. The [follow-up integrated record](session_logs/2026-09-21_dependency_kind_integrated_followup.json) records the repaired source and passing integrated gate; remaining qualification is tracked in CAMPAIGN.

The [power-manager descendant VIF checkpoint](session_logs/2026-09-21_pwrmgr_descendant_vif_focus.json) records paired focused runtime tests and the next pinned application boundary. Broad qualification for this new increment remains pending.

The current large-range distribution candidate and GPIO traffic evidence are recorded in [the 2026-09-21 focus checkpoint](session_logs/2026-09-21_exact_large_dist_focus.json). All required local gates passed on the recorded frozen source; CI awaits publication.
