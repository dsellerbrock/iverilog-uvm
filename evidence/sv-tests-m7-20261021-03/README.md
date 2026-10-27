# M7 no-regression sv-tests rerun — attempt 03

This fresh replacement follows job 3625, which built the pinned source successfully but stopped before tests because an extracted tarball was queried for Git metadata it does not contain. The fix removes that pre-init query; the corpus archive remains pinned by SHA-256, then the harness creates the synthetic Git snapshot required by the existing runner.

Pinned source: `10f3a0a2509d0852c2556cb662fb0025121fb2d` (tree `865b68d3317a817fab97961dec52f4bdc7e41568`). Pinned sv-tests corpus: `c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7`, archive SHA-256 `3924ac0ef31a1cd3d39bb6942b4b313b690468f9ae296210f6e9e3093b640ac5`; recorded UVM commit `656f20d087370a7c742e00188d20bbf30fa95339`.

Baseline: 1,027 tests, 1,022 passed, 5 known failures, with per-test logs in `../sv-tests-gap-20261013`.

The run requests 3 CPUs, 5 GiB, and 3 hours. `runner-safe` applies per-test timeouts and kills children. On completion, compare all per-test dispositions and archive the full raw logs.


Submitted Slurm job **3796** to `/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-m7-20261021-03` at 2026-10-21 19:09 UTC; initial state was PENDING. Requests 3 CPUs, 5 GiB, and 3 hours. Staged-file SHA-256: run.sbatch `bc3a38501a05b17f278876e82bb5037830dcc0a9b78a796b25f5e1b4e46d5cd1`, runner `b9eb97c0c36bc3922d10162d6394e29a6fb1a857cf4bdd4c596b83c40ed311db`, runner-safe `f271c6424a0592fde39ff5ae8c8f7c56b2a5587bfc10604a48c1b3815a4bc4af`.

## Attempt 03 harness failure — job 3796

Job 3796 completed all 1,027 paths but is **invalid as a source-build result**. The Python runner set `PATH` to `evidence/tool-bin`, while the Slurm script creates wrappers in `evidence/runners/bin`; `OUT_DIR` is `evidence/out`, so `runner-safe`'s additional `OUT_DIR/runners/bin` prefix also misses the wrapper directory. The suite therefore resolved system Icarus instead of the pinned build. Its 603/1,027 summary exactly matches the documented invalid Icarus 12.0 run; do not count it as a simulator regression or as the requested no-regression rerun.

Copied and SHA-256-verified the summary, test manifest and 1,083-entry raw-log archive in `attempt-3796-invalid/`. Source and tool provenance record main `10f3a0a2509d0852c2556cb662fb0025121fb2d`, the pinned corpus and the built Icarus 13.0 binaries. Job 3796 used the staged runner hash recorded above; the corrected runner in attempt 04 searches `evidence/runners/bin` and asserts both names resolve to the executable wrappers before launching tests. Python compilation, shell syntax checks, and a wrapper-path self-check passed; attempt 04 completed the required rerun below.

## Corrected attempt 04

Submitted Slurm job **3799** at 2026-10-21 19:18 UTC (3 CPUs, 5 GiB, 3 hours) with the fixed runner path and preflight resolution checks. Staged script hashes: `run.sbatch` `e3c2f6dfd3f7f2bfbd9218ececb1091dee439e7e3c53e7fca91cca9711f2c81a`; `run-local.sh` `9be9e5ddbeb36d2e62984157e4bf2957f97cd73f1e1b38f9f3e0db98024d5aa0`; runner `4b98093938ef77c155e7b6b4fe593e7619ced4242dca61281ce3c3e6c3e6a158`; `runner-safe` `f271c6424a0592fde39ff5ae8c8f7c56b2a5587bfc10604a48c1b3815a4bc4af`. It started immediately and completed successfully at the harness level.

Job 3799 completed all 1,027 cases on DAN-DESKTOP using Icarus/VVP 13.0-devel at source `10f3a0a2509d0852c2556cb662fb0025121fb2d`. The source-built binaries were `iverilog` SHA-256 `6cc9b37a3db05350fa03b7266d945c9a855989a2ac770f46d3ab03183baa8d0a` and `vvp` SHA-256 `2af12e13fb05d11fb2e9f9af52c9fda578fb26d2b6a7346170179633b775adf2`. Summary: 1,022 passed, the same 5 failed, 99.51%. The test manifest is byte-identical to the baseline; a per-test comparison of `applicable`, `test_passed`, `result_class`, `mode`, `rc`, and `tool_success` found 0 changed dispositions, 0 regressions, and 0 improvements across all 1,027 paths. The summary JSON also matches the baseline exactly. Checksums were verified after copying the summary, manifest and raw-log archive into `../sv-tests-m7-20261021-04/results/`; environment, provenance, scheduler, clone, configure, build, install and corpus-hash logs are retained there as well. After capture, the remote source/install/corpus/evidence trees (2,077,639,323 bytes) were removed; `/home/dsell` free space increased from 756,867,723,264 to 759,122,116,608 bytes.
