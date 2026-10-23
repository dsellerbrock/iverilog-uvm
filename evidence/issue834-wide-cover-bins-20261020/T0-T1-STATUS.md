# #834 T0/T1 checkpoint

Feature source: base `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, plus the WIP patch and the four-symbol `ivl.def` export fix (SHA-256 `04e9f34a6852a5eba0f9e605fdf7854de376953cfccf3239eab1b3cc242ccb31`). No goldens changed.

- Build: Slurm job 3611 built the feature WIP with `make -j2` successfully. This build preceded the later `ivl.def`-only export-list change; the resulting Linux build behavior is unchanged, and the export list is checked by the T0 smoke below.
- T0: Slurm job 3613 completed `ci/run-smoke.sh` with exit 0. Regressions 56/56 passed, VPI 133/133 passed, negative suite 152/152 passed, all runtime checks/reproducers passed, and `run_covgrp_exports.py` reported all 80 covergroup API functions exported.
- T1: Slurm job 3615 used pinned Icarus 13.0-devel and the preserved six-case list. Wide explicit ranges, exact-cross controls, and automatic-bin controls passed in both `-g2017` and `-g2023` (6/6).
- Current range-regression registration: JSON passed 2/2 in Slurm job 3620. The first legacy rerun (3621) exposed a test-list conflict: `-stop` selects `top`, overriding the fourth-field module name. After removing `-stop` from the two new rows, Slurm job 3622's instrumented legacy runner printed the exact `-s sv_covergroup_wide_range_bins` command for both editions and passed 2/2. The prior 3621 failure was harness configuration, not a simulator result; raw logs are preserved in attempts 13 and 14.
- Toolchain-path confirmation: job 3623 repeated the corrected legacy cases with a wrapper injecting `-B` to the shared read-only toolchain under `/home/dsell/toolchains`; both editions passed 2/2. This removes dependency on the old build install path. Exact hashes and logs are in attempt 15.
- Invalid harness attempts are preserved: job 3611 used the wrong install path; job 3613's T1 manifest used `true`; job 3614 selected system Icarus 12 because `PATH` was omitted. None is a simulator test failure. Their triage and raw logs remain alongside these results.

Windows lanes have not yet run. Since this change adds `ivl.def` exports, run MINGW64, UCRT64, and CLANG64 on the pushed PR branch before merge.

## Latest WIP after ignore-bin edge fixes

- Exact source snapshot: base fb584a251dd4cc91e56a75be662ccd5ee05c64e9, patch SHA-256 827e702bd88f3a597a0a9ff640c078830b568d9aca0f3a3d5ae7a02bb52bf22e; new regression overlay SHA-256 35a2b375b88892201d0c0cdcfd83eeb0d08ce9d564d836026079d1ec0a3e0410. No code changed between jobs 3632 and 3634.
- Job 3632: all six focused JSON cases and both legacy regressions passed. Its T0 attempt used the wrong install prefix and omitted the compiler from PATH, so those smoke results are invalid and superseded by job 3634.
- Job 3634: build succeeded with GNU time MaxRSS 1,689,532 KiB; T0 smoke returned 0 with 68 PASS lines and no FAIL lines. The smoke itself took 45.91 seconds; total script wall time was 261 seconds.
- Current focused verification is green for T0 and T1 in both 2017 and 2023. Detailed logs and hashes are in attempts 16 and 17. No goldens changed.
- Windows lanes have not run; they remain required before merge because the feature adds ivl.def exports.
