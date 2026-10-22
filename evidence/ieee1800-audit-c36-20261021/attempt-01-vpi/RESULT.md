# Result — Slurm job 3672

## Outcome

The VPI shared module built successfully, and the design compiled and ran under both `-g2017` and `-g2023`. Each edition printed exactly:

```text
V1 5 1
V2 9
V3 2
V4 3
```

This exercises successful system-task registration/invocation (§38.37), simulator-info retrieval (§38.17), top-level handle lookup (§38.21), value get/put with `vpiNoDelay` (§§38.15, 38.34), net iteration/scanning (§§38.23, 38.40), and three later `cbValueChange` deliveries (§§38.36, 38.36.1). This is evidence only for these paths, not for all VPI APIs in Clause 38.

The VPI module build emitted three GCC `-Wmissing-field-initializers` warnings for intentionally zero-initialized trailing fields in `s_vpi_time`/`s_vpi_value`; it exited 0. Both HDL compiles and both simulator runs had empty stderr and exit 0. The full scheduler output and per-step stdout/stderr are preserved in `slurm-3672-logs/`.

## Reproduction and provenance

- Host: DAN-DESKTOP, Slurm job 3672; submitted 2026-10-21 01:25 MDT; completed 01:25 MDT in 1 second with `ExitCode=0:0`.
- Resources: 1 CPU, 1 GiB requested, 10-minute limit. Per-step timeouts: VPI build 60 s; compile and simulation 30 s each.
- Toolchain: Icarus 13.0-devel, source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9` (ancestor of `origin/main` at probe time, `10f3a0a2509d0852c2556cb662fb0025121fb2d`); binaries and VPI headers/libraries from `/home/dsell/toolchains/iverilog-fb584a25-20261020/`.
- Audit checkout HEAD: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`, with unrelated ongoing audit changes in the worktree. Only the two explicit probe inputs were staged for the job.
- Input hashes: `p36.sv` `b283364cdf1f36eedea26a31e24c3bf6ee9bae6757a8d2ec9131c8eeb65b872a`; `vpi_basic.c` `239a846e0c5b529e2bc80201d77946b1d70fb07694b5777072f820e324f3fa9e`.
- Harness: [`run.sbatch`](run.sbatch), SHA-256 `0a7337dd812ccba481553f3631bb07278db599927b93231993656dc848e8d62c`. The pinned `iverilog-vpi` wrapper embeds a stale include/library path from a retired run directory, so the command passes explicit `-I/home/dsell/toolchains/.../include/iverilog` and `-L/home/dsell/toolchains/.../lib` overrides. The actual build succeeded using the shared read-only toolchain.

## Classification

Pre-file open+closed issue search is recorded in [`DEDUPE.md`](DEDUPE.md). No exact existing issue matched. The lead classified the exercised routine paths as `IMPLEMENTED (tested subset)` in both editions. There is no new issue. The matrix has one row per exercised routine, keeps Clause 38 `PARTIAL-ASSESSED`, treats Clause 36 as covered by those routine rows, and leaves Clause 37 unassessed. The second-pass paths are combined into the existing §38.34 and §38.36 rows.
