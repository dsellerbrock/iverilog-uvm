# WP3 `%cast2` performance screen

**Status: instruction screen qualified; JSON-gate environment discrepancy and
final wall medians remain open.** This candidate replaces the per-bit `%cast2` loop
with an A/B-plane operation over the existing vector words. The focused test
exhausts all four-state 8-bit inputs and checks widths around word boundaries.

## Pinned input

- Campaign and measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.
- Build the reference and candidate from this same base. The candidate is this
  base plus the recorded `%cast2` source and test changes.
- Do not rebase during measurement. If the candidate qualifies, rebase exactly
  once immediately before merge and follow the pre-merge path-diff rule in
  `docs/performance/PERFORMANCE_PLAN.md`.

## Attempts

- Run 1, Slurm job 1224: both builds completed, then the screen stopped before
  testing because the reference archive lacked the new test fixture. It
  produced no timing result. The build and error logs are in [`run-r1/`](run-r1/).
- Run 2, Slurm job 1226: both builds and the cast regression passed; 17 of 18
  benchmark outputs matched. The candidate `waveform_fst` run exited 139 under
  Callgrind, so the instruction screen is not a valid qualification. The
  `behav` count fell 14.079590% (94,553,323,869 to 81,240,603,069 Ir); the
  largest other change was a 1.920356% decrease in `classq`. The FST failure
  still blocks acceptance. Tables, profiles, logs and source hashes are in
  [`run-r2/`](run-r2/).
- FST diagnostic 1, Slurm job 1237: both runtimes rejected the FST flags because
  this diagnostic passed them before the `.vvp` program. It did not simulate;
  the invocation and output are preserved in [`fst-diag1/`](fst-diag1/).
- FST diagnostic 2, Slurm job 1238: using the hotspot runner's argument order,
  both pinned runtimes exited 0 and produced byte-identical stdout, stderr and
  FST files without Callgrind. Evidence is in [`fst-diag2/`](fst-diag2/).
- FST Callgrind retry, Slurm job 1239: both pinned runtimes exited 0 under the
  same Valgrind and `/usr/bin/time` wrappers, with matching outputs. Its counts
  are within 0.000016% of the full-run profiles; that successful pair supplies
  the `waveform_fst` row in [`validated-instruction-counts.csv`](validated-instruction-counts.csv).

The combined screen has all 18 byte-identical outputs, a 14.079590% `behav`
instruction reduction, and no instruction-count regression on another
benchmark. The authoritative combined result is
[`validated-screen-status.txt`](validated-screen-status.txt). The first full
runner invocation remains recorded with its candidate FST exit 139; the
separate successful FST pair completes that missing row.

## Correctness gates

- Linux job 1242 built and installed the candidate, passed the FPGA target
  install, legacy ivtest gate, and real-DPI UVM regression. Its full JSON run
  reported 16 failures and returned 16. Job 1246 rebuilt the pinned reference
  and reran exactly those cases on both runtimes; all 16 results matched byte
  for byte. However, A3's gate reports zero failures, so this Slurm-environment
  discrepancy remains open and must be reconciled before merge. See
  [`full-gates/linux-1242/`](full-gates/linux-1242/) and
  [`full-gates/json-baseline-1246/`](full-gates/json-baseline-1246/).
- macOS ARM64 build, install, UVM install, and FPGA target install completed.
  Logs and tool hashes are in [`macos-gates/`](macos-gates/).

The source and correctness evidence remain pinned to
`c7ebca768c21c251d9c165c9aff0e363768030b1`. Do not rebase before final wall
medians. If it qualifies, rebase exactly once immediately before merge and
follow the pre-merge path-diff rule in `docs/performance/PERFORMANCE_PLAN.md`.

Final wall job 1261 failed before any benchmark ran: the wrapper invoked the
Bash `run.sh` through Python. Its empty result and Slurm log are preserved in
[`final-wall/attempt-1261/`](final-wall/attempt-1261/). Corrected job 1263 uses
[`final-wall/run-final-wall-r2.sbatch`](final-wall/run-final-wall-r2.sbatch)
with the same paired installs built from this pin. It compiles each benchmark
once with the reference compiler, runs three interleaved pairs, and records
wall time, instructions where available, RSS, and output hashes. It is running
alongside exact-head CI within the three-job A5 limit.

## Gate

For promotion, the candidate must retain identical benchmark outputs, at least
10% fewer `behav` instructions, no other benchmark regression above 2%, final
wall-time medians, and reconciled JSON-gate results. Do not merge while the
Slurm/A3 JSON discrepancy remains unexplained.
