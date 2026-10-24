# Result — Slurm job 3673

## Outcome

The VPI module built and both paired-edition designs compiled and ran with exit 0 and empty stderr. Each edition printed exactly:

```text
FULLNAME p36b.r
SIZE 8
MEM2 2
IMMEDIATE 2
REMOVE 1
AT6 7
TIME 0 10
REMOVED_CALLS 0
TIME_CALLS 1
FINISH 1
```

`AFTER_FINISH` did not print. The probe therefore observes the tested paths for §§38.4, 38.6, 38.11, 38.13, 38.19, 38.34, 38.36.2, and 38.39 in both editions. For §38.34 it confirms delayed visibility of one inertial write; it does not test cancellation of competing scheduled writes.

## Reproduction and provenance

- Host: DAN-DESKTOP, Slurm job 3673; submitted 2026-10-21 01:29 MDT; completed 01:29 MDT in 1 second with `ExitCode=0:0`.
- Resources: 1 CPU, 1 GiB requested, 10-minute limit. Per-step timeouts: VPI build 60 s; compile and simulation 30 s each.
- Toolchain: Icarus 13.0-devel, source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; binaries and VPI headers/libraries from `/home/dsell/toolchains/iverilog-fb584a25-20261020/`. The source commit is an ancestor of `origin/main` `10f3a0a2509d0852c2556cb662fb0025121fb2d`.
- Audit checkout HEAD: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; only the two explicit probe inputs were staged for the job.
- Input hashes: `p36b.sv` `827f631600783b27e93a11f5e0d42be20696be19113add6de2250c51cf5c7318`; `vpi_more.c` `a26d77cb7ae2aa150230965aae9a15cc1df6419c1cfe59ae25c9f9297866879d`.
- Harness: [`run.sbatch`](run.sbatch), SHA-256 `0e8745dc6ad400a57dfa4cc95ef07843f71dd4c5368eb91c5a82a51770f6d2b4`. It supplies explicit include/library overrides because the pinned `iverilog-vpi` script embeds an include/library path from a retired run directory. The build succeeded from the shared read-only toolchain.
- Raw scheduler and per-step logs: `slurm-3673-logs/`. No build warnings were emitted.

## Classification

The pre-file open+closed issue search is in [`DEDUPE.md`](DEDUPE.md). The only result was unrelated closed issue #501 about VPI source file/line metadata. No exact existing issue was found. The audit lead classified the exercised paths as `IMPLEMENTED (tested subset)` in both editions. No issue is warranted. The matrix merges these paths into the existing §38.34 and §38.36 rows, adds rows for §§38.4, 38.6, 38.11, 38.13, 38.19, and 38.39, and records the §38 parent as partially assessed.
