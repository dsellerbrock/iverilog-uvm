# WP0 evidence

## Pinned source

| Role | Revision |
| --- | --- |
| Measurement and correctness base | `f9f8e0a79f230f38da6cbb4445994ad1075ad531` |
| WP0 candidate | `a5aad31659540d6a4c67bbaeffbeaa484b31f442` |
| UVM core submodule | `78c06547a2a0a29b3dc9dcafae62b75b2ff61544` |

The reference and candidate toolchains were built from these revisions on the
pinned base. No rebase occurred during correctness or performance
measurement.

## Correctness gates

Job 1048 built the reference, stats-off candidate, and stats-on candidate, then
passed the stats-symbol and stats-output checks, `make check`, the vendored
ivtest sweep, FPGA install, and the JSON/VVP comparison. The JSON candidate ran
4,643 tests; its 16 failures were all reproduced by targeted baseline runs, so
the baseline delta was zero. The UVM stage in job 1048 exposed a harness
working-directory error and is not counted as a UVM result.

The corrected UVM gate ran from the candidate source root in job 1052. It
passed 367 tests with zero failures or skips and confirmed the real DPI
umbrella. Job 1051 is preserved as an OOM attempt: its 2 GiB memory cap caused
56 compiler kills; the corrected run used 8 GiB and passed.

Attempt logs and provenance are preserved under
[`full-gates/run-f9f8e0a/attempts`](full-gates/run-f9f8e0a/attempts). The
correctness bundle hashes are recorded in each attempt's `attempt-status.txt`.

## Performance measurement

The pinned-base comparison uses the job 1048 `baseline-install` and
`install-off` toolchains and the benchmark corpus from the candidate archive.
It ran a one-pair screen followed by five interleaved pairs on one CPU, with
`+ntb_random_seed=73014` and temporary files under `/dev/shm`. `perf stat` was
available; the hardware instruction counter was unsupported, so task-clock was
the primary metric. The accepted run requires byte-identical outputs for all
18 workloads, every sample under 10 seconds, and reference task-clock spread
no greater than 5 percent. Job 1058 passed all gates on pinned base
`f9f8e0a79f230f38da6cbb4445994ad1075ad531`.

| Benchmark | Reference wall (s) | Candidate wall (s) | Reference task-clock (ms) | Candidate task-clock (ms) | Reference spread | Ref/candidate ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| behav | 4.470 | 4.473 | 4437.89 | 4444.63 | 0.25% | 0.9985x |
| classq | 5.723 | 5.673 | 5679.72 | 5636.79 | 1.45% | 1.0076x |
| fork_heavy | 0.514 | 0.516 | 465.18 | 465.38 | 1.37% | 0.9996x |
| gate_strength | 1.466 | 1.467 | 1452.46 | 1456.05 | 0.54% | 0.9975x |
| io_text | 0.114 | 0.114 | 65.62 | 65.82 | 1.17% | 0.9970x |
| large_memory | 0.114 | 0.114 | 94.41 | 94.79 | 0.58% | 0.9960x |
| multi_clock | 0.315 | 0.316 | 286.24 | 286.79 | 0.56% | 0.9981x |
| randomize_dv_txn | 4.980 | 4.977 | 4923.92 | 4927.52 | 0.81% | 0.9993x |
| randomize_z3 | 1.320 | 1.318 | 1301.32 | 1291.79 | 2.87% | 1.0074x |
| rtl_alu | 3.822 | 3.822 | 3807.65 | 3809.53 | 0.49% | 0.9995x |
| rtl_pipe | 7.178 | 7.177 | 7145.56 | 7141.26 | 2.49% | 1.0006x |
| strings_aa_queue | 3.118 | 3.120 | 3088.20 | 3095.19 | 0.92% | 0.9977x |
| uvm_config_factory | 0.616 | 0.616 | 593.91 | 596.08 | 1.34% | 0.9964x |
| uvm_traffic | 3.523 | 3.523 | 3497.44 | 3495.48 | 2.92% | 1.0006x |
| vpi_callbacks | 5.123 | 5.124 | 5091.08 | 5082.60 | 0.66% | 1.0017x |
| waveform_fst | 0.715 | 0.715 | 660.04 | 659.91 | 0.73% | 1.0002x |
| waveform_vcd | 0.615 | 0.615 | 586.29 | 587.80 | 1.43% | 0.9974x |
| wide_vectors | 0.264 | 0.264 | 232.19 | 231.84 | 0.61% | 1.0015x |

Raw results: [`result.csv`](measurements/f9f8e0a/job1058-stable/result.csv),
[`result.json`](measurements/f9f8e0a/job1058-stable/result.json), and the
complete [job 1058 evidence bundle](measurements/f9f8e0a/job1058-stable/attempt-logs.tgz).

The disabled-build instruction-count A/B on the same pinned base preserved
byte-identical output and exact counts for the selected VVP hot paths. The
whole-process Callgrind totals differ by 70 instructions; the stats-off build
has no performance-counter symbols. See the [instruction-count evidence](instruction-ab/README.md)
for raw profiles, exact counts, and attempt notes.

Earlier attempts 1053, 1055, 1056, and 1057 are retained under `attempts/`;
each passed output equality and the 10-second cap but failed the stability
gate. Job 1058 is the accepted measurement. The ratios are effectively neutral;
WP0 adds measurement infrastructure and does not claim a runtime speedup.

This WP adds measurement infrastructure and does not claim a runtime speedup.
