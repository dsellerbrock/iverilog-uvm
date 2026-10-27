# Normalized Clause 32 SDF probe results

- Slurm job 3708 on DAN-DESKTOP; 1 CPU, 1 GiB; toolchain base `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`.
- Icarus SHA-256 `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`; VVP SHA-256 `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`.
- All 14 compile/run cases completed in both editions. Every log had zero `SDF ERROR` occurrences. `HARNESS_STATUS=0`; Slurm no longer listed job 3708. Accounting is disabled on this host.

Results, identical under `-g2017` and `-g2023`:

| Probe | Expected | Observed | Result |
| --- | --- | --- | --- |
| SDF `TIMINGCHECK SETUP`, data 3 ns before clock | Annotated 5 ns check violates once; unannotated 1 ns control does not | `SDF WARNING: ... TIMINGCHECK not supported.`; 0 violations in annotated and control | Feature gap |
| `mtm_spec=MINIMUM` | rise/fall 1/4 ns | 2/5 ns | Feature gap |
| `mtm_spec=TYPICAL` | rise/fall 2/5 ns | 2/5 ns | Pass |
| `mtm_spec=MAXIMUM` | rise/fall 3/6 ns | 2/5 ns | Feature gap |
| scale factors `2.0:2.0:2.0`, `FROM_TYPICAL` | rise/fall 4/10 ns | 2/5 ns | Feature gap |
| SDF `INTERCONNECT u1/y u2/a (3)` | load arrives at t13 after t10 stimulus | `Y 13 1` | Pass |

Every `MINIMUM`, `TYPICAL`, `MAXIMUM`, and scaling call prints `SDF WARNING: ... $sdf_annotate currently only uses the first two argument.` The normalized run produced eight edition-specific expectation mismatches: timing check, minimum, maximum, and scaling once in each edition. Typical selection and interconnect passed. Raw logs, normalized signal-only outputs, and per-file SDF error counts are in [`raw-slurm/`](raw-slurm/).
