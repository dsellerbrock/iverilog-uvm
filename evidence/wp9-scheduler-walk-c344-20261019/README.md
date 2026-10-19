# WP9 scheduler time-list walk screen

Measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc`.

WP9 changes the time queue only if insertion walks are long. The existing
`--enable-perf-stats` counters were built from this pinned source and run once
on all 18 sim-hotspots workloads. Slurm job 2984 built the counter-enabled
runtime but stopped at `large_memory` because the collector had not created its
staged-input directory; its partial counts are preserved but not used. Job
2985 reused that build and completed all 18 workloads successfully.

| Workload | Insertions | Total walk steps | Average steps | Maximum |
| --- | ---: | ---: | ---: | ---: |
| `multi_clock` | 5,978,390 | 6,893,806 | 1.153121 | 7 |
| `uvm_traffic` | 95,529 | 20,006 | 0.209423 | 2 |
| `fork_heavy` | 4,097 | 4,095 | 0.999512 | 1 |
| `rtl_pipe` | 185,523,473 | 480,004 | 0.002587 | 1 |
| `rtl_alu` | 84,004,275 | 200,004 | 0.002381 | 1 |
| `gate_strength` | 41,381,637 | 0 | 0 | 0 |

Across the full corpus, the maximum walk was 7 nodes and the average was at
most 1.16. The queue is not a useful target for a data-structure rewrite, so
WP9 is rejected without a source change. These are operation counts from an
instrumented build, not throughput measurements.

The complete 18-workload counter table and extracted JSON are in
[`attempts/job-2985-r2/results/corpus/`](attempts/job-2985-r2/results/corpus/).
Job 2985's build and run logs, binary hashes, and input provenance are kept in
[`attempts/job-2985-r2/`](attempts/job-2985-r2/). The failed collector attempt
is recorded under [`attempts/job-2984-r1/`](attempts/job-2984-r1/). The exact
base source archive, UVM inputs, collector, and Slurm scripts are in
[`input/`](input/) and [`submit/`](submit/).

## Caliptra check — Slurm job 2992

The same stats-enabled build ran all three top-level Caliptra tests through the
fixed mcycle window 100–2,100 on pinned base `c344d20197a569dea8936bad95de3d185b1e78dc`.
The scheduler recorded zero time-list walk steps in every test, despite about
316 million insertions per test:

| Test | Insertions | Total walk steps | Maximum walk |
| --- | ---: | ---: | ---: |
| `smoke_test_dma_aes_gcm_short_1_dword` | 316,516,459 | 0 | 0 |
| `smoke_test_sha256` | 316,258,679 | 0 | 0 |
| `cptra_ss_test_rom` | 316,458,665 | 0 | 0 |

Each window covered exactly 2,000 mcycles; job 2992 exited successfully and
verified its input checksums. This confirms the short queue walks on the
18-workload corpus also hold for the measured Caliptra firmware windows.
The full CSV/JSON counters, per-test logs, binary hashes, and provenance are in
[`attempts/job-2992-r2/`](attempts/job-2992-r2/).
