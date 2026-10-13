# Pinned sv-tests gap classification — 2026-10-13

## Corrected run

The pinned corpus is sv-tests commit c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7 with UVM commit 656f20d087370a7c742e00188d20bbf30fa95339. Corrected Slurm job 816 built Icarus source commit db458c438eca253fb1b3110f671fe3800e33b7a0 (tree 2cb6260f02c1680196cca51d76e6e429e3b738d5), then verified that both suite wrappers resolved to that build. The compiler SHA-256 is be07507e40469183634d4773e68af00d76aeac6147eaecfdf8f4381d573f26b7; VVP SHA-256 is 9318dbe5d0f019c95235df400a9da60ca84f4d41b3493f8684fd1cf3f753fa75.

The runner completed all 1,027 applicable cases: 1,022 runner-passed and 5 runner-failed (99.51% under this runner’s pass definition). The result classes are:

| Runner result class | Cases |
| --- | ---: |
| ACCEPTANCE_ONLY | 95 |
| EXPECTED_REJECT_UNVERIFIED | 76 |
| STATIC_ACCEPT | 657 |
| VERIFIED_RUNTIME | 194 |
| UNEXPECTED_ACCEPT | 3 |
| SEMANTIC_FAIL | 2 |
| **Total** | **1,027** |

This is a runner result, not a claim that every case received semantic verification. For example, a UVM test classified ACCEPTANCE_ONLY completed with missing-DPI-symbol errors in its log. The runner’s pass count should therefore not be described as full IEEE conformance.

## Why the earlier 424-row table is superseded

Slurm job 792 built the source tree above, but the suite did not run that build. Its batch script put wrappers in RUN_DIR/tool-bin while the runner searched OUT_DIR/tool-bin and OUT_DIR/runners/bin. Those locations were empty, so PATH selected /usr/bin/iverilog, Icarus 12.0, SHA-256 a6681e0b577dcfc4ea83d1591a5714710b0b3535ebb36491ee8177553bab9631.

The exact pinned UVM source and test 16.10--property-local-var-uvm.sv reproduce the distinction: Icarus 12.0 rejects uvm_hdl.svh at line 77, while the source-built Icarus 13.0 compiles it and emits the imported DPI call. The source tree used by both runs is identical. Thus 603/1,027 and its 424 nonpassing rows describe the system Icarus 12.0 invocation, not the Icarus source build. Those raw artifacts are preserved for audit; that ranking cannot select source-build feature work.

## Historical 424-case classification and current-source crosswalk

The 424 cases remain classified by feature area and observed root cause in [the historical crosswalk CSV](sv_tests_gap_2026-10-13_historical_424.csv). Each row preserves its Icarus 12.0 result and raw-log member, then adds the result and raw-log member from corrected source-build job 816. The crosswalk's `manual_crosswalk_log_check` marks 20 cases across all nine feature areas that I compared against both raw logs.

The old failure counts and the corrected runner classes for those same test paths are:

| Historical feature area | Icarus 12.0 nonpasses | Corrected `STATIC_ACCEPT` | `VERIFIED_RUNTIME` | `ACCEPTANCE_ONLY` | `EXPECTED_REJECT_UNVERIFIED` | `SEMANTIC_FAIL` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| UVM DPI import | 101 | 64 | 0 | 37 | 0 | 0 |
| Arrays / aggregates / unions | 97 | 28 | 61 | 2 | 5 | 1 |
| Constraints / randomization | 58 | 42 | 12 | 2 | 2 | 0 |
| Class / OO / type resolution | 56 | 53 | 3 | 0 | 0 | 0 |
| Procedural / events / timing | 35 | 28 | 5 | 0 | 1 | 1 |
| Expressions / types / operators | 33 | 23 | 5 | 1 | 4 | 0 |
| Assertions / SVA | 19 | 16 | 0 | 3 | 0 | 0 |
| Directives / coverage / interface / system functions | 18 | 1 | 4 | 6 | 7 | 0 |
| Other / testbench | 7 | 7 | 0 | 0 | 0 | 0 |
| **Total** | **424** | **262** | **90** | **51** | **19** | **2** |

These are runner classes, not equivalent levels of semantic verification. In corrected-run job 816, all 37 UVM rows classified `ACCEPTANCE_ONLY` had missing `uvm_dpi_*` symbols because the runner compiled raw UVM sources but did not load `uvm_dpi.vpi`; those rows did not demonstrate successful UVM execution. A focused follow-up loaded the module and reran all 37 cases: all compiled and returned zero, with no timeout or missing-DPI-symbol log, and the sv-tests parser accepted 34. The three remaining assertion markers are not confirmed simulator gaps: two tests expect `assert final`/`assert #0` to sample after a nonblocking update, while IEEE 1800-2023 §16.4 says the expression is evaluated when the deferred assertion statement is processed; the third test's pinned source says its assertion fails on all tested simulators. See the [UVM DPI follow-up evidence](../../evidence/sv-tests-gap-20261013/uvm-dpi-followup/README.md). The project's [UVM DPI instructions](../uvm_frontend.md) document the required module-loading paths.

`ACCEPTANCE_ONLY` also does not mean that every source test lacks an oracle. The [positive SVA cases](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-16/16.10--property-local-var.sv) use `$error` failure actions and finish without one; the [randsequence case](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-18/18.17--random-sequence-generation-randsequence_2.sv) uses `$stop` for an out-of-range result and likewise completes without stopping. Other cases explicitly say they do not verify results, such as [inside-set membership](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-11/simple/11.4.13--simple_set_member-sim.sv). The [coverage routine case](https://github.com/chipsalliance/sv-tests/blob/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-20/20.14--coverage.sv) reports `SV_COV_NOCOV` when no coverage is instrumented; IEEE 1800-2017 and 1800-2023 §40.3.2 define that result when coverage is unavailable. The [file-read cases](https://github.com/chipsalliance/sv-tests/tree/c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7/tests/chapter-21) invoke routines without checking return values; `$fgets` and `$fread` even use write-only files. These raw outcomes do not supply five additional simulator-defect categories.

The corrected source build includes the merged batch-10 code. The crosswalk records present-day outcomes for the historical paths; it does not attribute those outcomes to any individual change. Within this evidence, the two corrected-run failures are a tagged-union assertion-parser failure and a time-zero event race, while the large historical groups no longer provide five confirmed, source-build simulator-defect categories. Do not use the Icarus 12.0 ranking as a claim that five such source-build gaps remain.

## The five runner-failed cases

The corrected CSV has one row per runner-failed test, its raw-log member, and the disposition supported by the pinned source and log.

| Test | Runner class | Classification |
| --- | --- | --- |
| tests/chapter-16/16.15--property-disable-iff-fail.sv | UNEXPECTED_ACCEPT | The test’s assertion action calls $error; the log contains repeated ERROR property-check messages and the simulator exits 0. IEEE 1800-2017 §20.10 requires $error to be a run-time error; it specifies an error-code termination for $fatal. This is a test-oracle mismatch, not evidence that the assertion did not fire. |
| tests/chapter-16/16.10--property-local-var-fail.sv | UNEXPECTED_ACCEPT | Same oracle mismatch: the log contains repeated ERROR property-check messages from the $error action; exit status is 0. |
| tests/chapter-16/16.10--sequence-local-var-fail.sv | UNEXPECTED_ACCEPT | Same oracle mismatch: the log contains repeated ERROR sequence-check messages from the $error action; exit status is 0. |
| tests/chapter-7/unions/tagged/basic.sv | SEMANTIC_FAIL | VVP prints the same tagged-union value on both sides of the test’s %p comparison. The sv-tests log parser passes the :assert: text to Python eval, which cannot parse this SystemVerilog tagged-union representation. This is a test-harness parser failure. |
| tests/chapter-9/9.4.2--event_control_sim_minimal.sv | SEMANTIC_FAIL | The initial process triggers e at time zero while an independent always @(e) process has not been synchronized as waiting; the observed i remains 0. IEEE 1800-2017 §15.5.1 says -> unblocks processes “currently waiting on that event.” A separate control delayed the trigger until after the waiter was armed and passed with i=1. This is a test race, not a confirmed simulator defect. |

None of the five corrected-run nonpasses is a confirmed simulator defect. The corrected corpus evidence therefore does not support ranking five simulator-fixable categories or creating feature PRs to satisfy that quota. The previous 424-row ranking cannot be used for that purpose because it analyzed Icarus 12.0. The milestone’s feature target and its 603 starting baseline need to be re-scoped before selecting work.

## Manual source and raw-log audit

I checked the pinned source at c4229f3 and the corresponding raw archive member for all five runner-failed rows and these 15 runner-passed samples. That is 20 source/log checks. The raw archive contains a log for every case; member paths use Icarus/ followed by the test path without its leading tests/ directory and with .log appended.

| Test | Runner class | Source/log finding |
| --- | --- | --- |
| tests/chapter-16/16.15--property-disable-iff-fail.sv | UNEXPECTED_ACCEPT | $error action fires repeatedly; simulator rc=0. |
| tests/chapter-16/16.10--property-local-var-fail.sv | UNEXPECTED_ACCEPT | $error action fires repeatedly; simulator rc=0. |
| tests/chapter-16/16.10--sequence-local-var-fail.sv | UNEXPECTED_ACCEPT | $error action fires repeatedly; simulator rc=0. |
| tests/chapter-7/unions/tagged/basic.sv | SEMANTIC_FAIL | Tagged-union values print identically; parser cannot eval the assertion syntax. |
| tests/chapter-9/9.4.2--event_control_sim_minimal.sv | SEMANTIC_FAIL | Time-zero trigger runs before the waiter is synchronized; later control passes. |
| tests/chapter-20/20.15--dist_uniform.sv | ACCEPTANCE_ONLY | Command completes and prints a value; there is no :assert: check. |
| tests/chapter-21/21.6--value.sv | ACCEPTANCE_ONLY | Command completes; without a TEST plusarg it prints TEST not found. |
| tests/chapter-7/arrays/unpacked/ordering-methods/shuffle.sv | ACCEPTANCE_ONLY | Command completes and prints before/after arrays; there is no :assert: check. |
| tests/chapter-16/16.12--property-interface-prec-uvm.sv | ACCEPTANCE_ONLY | Runner marks completion as pass-class, but the log reports missing UVM DPI symbols; this shows the limit of acceptance-only results. |
| tests/chapter-8/8.26.3--type_access_implements_invalid.sv | EXPECTED_REJECT_UNVERIFIED | Rejected with the expected invalid implemented-type access syntax diagnostics. |
| tests/chapter-14/14.3--clocking-block-signals-error.sv | EXPECTED_REJECT_UNVERIFIED | Rejected because procedural assignments target wire outputs. |
| tests/sanity.sv | EXPECTED_REJECT_UNVERIFIED | Rejected with the expected malformed-instantiation syntax diagnostic. |
| tests/chapter-6/6.19--enum_xx_inv_order.sv | EXPECTED_REJECT_UNVERIFIED | Rejected because enum name c has no defined inferred value. |
| tests/chapter-12/12.6.2--if_pattern.sv | STATIC_ACCEPT | Elaboration succeeds; this case does not run simulation. |
| tests/chapter-8/8.20--virtual_method.sv | STATIC_ACCEPT | Elaboration succeeds; this case does not run simulation. |
| tests/chapter-20/20.10--fatal.sv | STATIC_ACCEPT | Parsing-only test succeeds as declared in its metadata. |
| tests/chapter-14/14.3--clocking-block-signals.sv | STATIC_ACCEPT | Elaboration succeeds for the logic-output control. |
| tests/chapter-12/12.8--continue.sv | VERIFIED_RUNTIME | Runtime assertion reports 255 == 255. |
| tests/chapter-20/20.8--clog2.sv | VERIFIED_RUNTIME | Runtime assertion reports 5 == 5. |
| tests/chapter-7/arrays/unpacked/reduction-methods/or.sv | VERIFIED_RUNTIME | Runtime assertions report the expected array values and reduction result. |

The corrected run summary, source/build provenance, runner scripts, raw logs, and event control outputs are in [the evidence directory](../../evidence/sv-tests-gap-20261013/README.md). The raw-log archive SHA-256 is 3555d678a47caa892791d6587aaec2647c1db77c419ff31131becf68eaf5a954.
