# WP0 performance evidence

Current WP0 campaign pin: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`. This
directory preserves earlier calibration attempts measured against
`47bc28987caaece4b176f610212f170290b3039c`; those results are historical and
are not the accepted comparison for PR #584. The accepted pinned-base evidence
is in [`perf-wp0-a5aad316`](../perf-wp0-a5aad316/README.md).

The candidate benchmark snapshot is commit `64eb2c8cd`; the reference is the merged WP0 baseline `47bc28987caaece4b176f610212f170290b3039c`. The candidate VVP binary is built from `281d1bca8`; `configure.ac` and `vvp/` are unchanged from that build through the measurement snapshot. Source manifests, commands, binary hashes, tool versions, and raw JSON are preserved under `attempts/`. Large console logs are gzip-compressed without changing their contents.

The run host was `DAN-DESKTOP` under Slurm. Linux `perf stat` could measure task-clock but reported hardware `instructions` as unsupported. Therefore task-clock is the primary metric for spread; wall time is reported as supporting evidence. No instruction-count result is claimed.

## Attempts

| Slurm job | Snapshot | Outcome |
| --- | --- | --- |
| 981 | early WP0 worktree | Verification stopped before measurement: the script checked `config.h` at the source root instead of `vvp/config.h`. The corrected path is used by later attempts. |
| 983 | early WP0 worktree | One-pair smoke passed output equality and the 10-second cap. One pair does not establish spread. |
| 985 | `dbc0c9bac` | Five pairs matched all outputs and stayed under 10 seconds. Baseline task-clock spread exceeded 5% on `rtl_pipe` (17.34%), `strings_aa_queue` (5.66%), and `waveform_fst` (11.89%). |
| 987 | `39d959d3a` | Stats-enabled build/symbol check, counters-disabled output identity, and JSON smoke passed. The later Z3-counter regression was added in `5edba2312` and is rerun in final gates. |
| 989 | `d80d93f83` | Five pairs matched all outputs and stayed under 10 seconds, but baseline task-clock spread exceeded 5% on `behav` (31.88%), `classq` (6.60%), `fork_heavy` (5.30%), `randomize_dv_txn` (5.09%), `randomize_z3` (12.50%), `rtl_alu` (5.23%), `uvm_traffic` (9.51%), and `vpi_callbacks` (7.56%). |
| 992 | `281d1bca8` | All 18 outputs matched. Depth 15 made `fork_heavy` take 54.66 seconds median on the reference (57.56 seconds maximum), above the 10-second cap; its task-clock spread was 28.57%. `strings_aa_queue` task-clock spread was 5.30%. This attempt motivated restoring fork depth 12 and increasing the strings/queue loop to 2.56 million entries. |
| 1000 | `64eb2c8cd` | The screen and five-pair run matched all 18 outputs and kept every sample under 10 seconds. Reference task-clock spread exceeded 5% on five rows; `randomize_z3` rose from 1341.46 to 1567.57 ms while its output hash stayed identical. See the gate summary and per-run analysis. |
| 1004–1005 | stats diagnostic | Setup mistakes: both probes used an older VVP install without performance-counter symbols, so they provide no counter-stability evidence. The corrected binary is hash-verified in job 1006. |
| 1006 | stats diagnostic | Five direct stats-enabled runs had identical stdout and identical Z3 counts: 800 contexts, 17,773 checks, and 1,718 model evaluations. This makes changing random draw counts unjustified. |
| 1007 | `64eb2c8cd` | All 18 outputs matched and all samples stayed below 10 seconds. Only `gate_strength` and `multi_clock` failed the reference task-clock spread gate (12.10% and 45.04%), each due to one isolated high sample. Their deterministic work is lengthened in the next calibration revision; see `attempts/job1007/diagnostic-analysis.txt`. |

The original gate summaries are kept alongside each result. For runs 985, 989, and 992, this table reports the campaign's primary metric; wall spread remains visible in the raw JSON.
