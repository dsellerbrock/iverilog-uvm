# WP0 calibration evidence

Current WP0 campaign pin: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`. This
directory preserves earlier calibration attempts measured against
`47bc28987caaece4b176f610212f170290b3039c`; those results are historical and
are not the accepted comparison for PR #584. The accepted pinned-base evidence
is in [`perf-wp0-a5aad316`](../perf-wp0-a5aad316/README.md).

This revision-scoped record covers the calibrated benchmark sources at
`a772c6bfc`. The reference VVP is from `47bc28987caaece4b176f610212f170290b3039c`;
the counters-off candidate VVP was built from runtime sources at `281d1bca8`,
which are unchanged by the benchmark calibration. The staged benchmark/UVM
source checksums match the local committed snapshot. Full tool versions,
runtime hashes, source manifests, scripts, JSON, and Slurm logs are recorded
per attempt.

The host was `DAN-DESKTOP` (Ubuntu under WSL2), using Slurm, one CPU pinned by
the runner, and an isolated source directory. Hardware `instructions` was
reported unsupported, so `task-clock` was the primary stability metric and
wall time is supporting evidence. No instruction-count claim is made.

## Attempts

| Job | Outcome |
| --- | --- |
| 1008 | Setup failure before compilation: the source manifest was verified from the wrong directory. No measurement. Exact script and logs are in `attempts/job1008/`. |
| 1009 | Setup failure before compilation: the host lacked the optional `z3` CLI used only for version capture. The runtime’s linked Z3 library was available. No measurement. Exact script and logs are in `attempts/job1009/`. |
| 1010 | One-pair screen passed, followed by five interleaved pairs. All 18 outputs matched, every sample remained below 10 seconds, and all reference task-clock spreads were at most 5%. Slurm completed with exit code 0. Results are in `attempts/job1010/`. |

Job 1010’s reference task-clock spread ranged from 0.22% (`randomize_dv_txn`)
to 2.85% (`rtl_alu`). `gate_strength` measured 1.416 s median and 0.47% spread;
`multi_clock` measured 0.315 s median and 0.61% spread. The previous snapshot’s
shorter versions had isolated spread failures; their full results and
root-cause notes remain in
[`evidence/perf-wp0-64eb2c8cd`](../perf-wp0-64eb2c8cd/README.md).

This work calibrates measurement resolution only. It does not claim a runtime
speedup, change simulation semantics, or change randomized draw counts.
