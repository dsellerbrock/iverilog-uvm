# §18.5.10 / §18.5.9 warned-heap uniformity measurement

This is the standard Figure 18-2 heap shape that emitted the “too large to enumerate” warning in job 3486. The harness must capture that warning; without it, the probe does not exercise the fallback in #843.

The initial `n=2000` pair (job 3727) timed out in both editions at 300 seconds, with the required fallback warning in each log. As directed, the same probe then ran with `n=1000` in paired editions (job 3729); both completed under the 300-second limit and emitted the fallback warning. The 5σ windows widen by √2: means 63.5 ±9.9, 127.0 ±9.9, and 191.5 ±9.9; count `v<32` 44.25 ±65.1. See `STANDARD.md`, `DEDUPE.md`, and `RESULT.md`.

Both jobs use 1 CPU, 128 MiB, and a 12-minute limit on DAN-DESKTOP: job 3727 ran `n=2000`; job 3729 reruns at `n=1000`. The memory request is based on the 41,348 KiB peak of related job 3486. Inputs were staged from branch `m7-1800-audit-c08`, HEAD `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; hashes are in `INPUT-SHA256SUMS.txt`. Toolchain: Icarus 13.0-devel at `/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb`, commit `cc25756d`, with `iverilog` SHA-256 `87bb417df23d260bcfde3fb372b4a80eaad69e4fd2eea1ffb8b0eff10f7af08e` and `vvp` SHA-256 `dfc193c466a70a0917a16ab4198a111de616657d6004de79456db2a4b603b437`.

The timed-out `n=2000` logs and scheduler output are preserved under `results-n2000/` and `slurm-3727.out`; the `n=1000` paired logs and scheduler output are under `results-n1000/` and `slurm-3729.out`.
