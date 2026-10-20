# WP7 tiered randomization

Pinned measurement base: `8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1`.
Measured candidate patch SHA-256: `4655a50f6b1700060dd87b92db87966ecb2112366a7d47323f9070b3d1447754`.
The final `SOLVER.md` was filled in after timing; no runtime code changed.

The current prototype adds only T0 for a class whose declared constraints are
all disabled. The five-tier counters are opt-in instrumentation. It does not
implement native T1/T2 sampling or reuse Z3 contexts for T3.

## Local functional and timing screen

On the local ARM64 host, the focused 400-call disabled-constraint fixture
produced byte-identical stdout and stderr from a solver-backed reference and
the candidate. Five interleaved wall-time runs had medians of 0.53724 s and
0.01963 s (27.37x); spreads were 17.60% and 54.26%, so this is only an
exploratory screen, not the Slurm campaign result. Reference and candidate
output SHA-256 was
`43c33e3238b9cd7adc626e0f899a028a9f30708fcc0cc34ec45cf8811ba7914f`.
The isolated T4 soft-only run also matched byte-for-byte; its output SHA-256
was `360f2bc1511a8440d1c28d1eb53ce364b0f12c06516ef07a5bc865fe611edd13`.

Opt-in tier-counter runs on the same local host reported; T3 denotes ordinary
hard constraints eligible for the proposed incremental path, but still using
a fresh Z3 context per call. Classification is not cached yet.

| Workload | Calls T0/T1/T2/T3/T4 | Z3 contexts |
| --- | ---: | ---: |
| `randomize_z3` (400 draws per class) | 0/0/0/800/0 | 800 |
| `randomize_dv_txn` (400 draws) | 0/0/0/400/0 | 400 |
| UVM `uvm_traffic` (5,000 items) | 5,000/0/0/0/0 | 0 |
| Disabled-constraint fixture (400 calls) | 400/0/0/0/0 | 0 |
| Soft-only fixture (400 calls) | 0/0/0/0/400 | 400 |

The UVM traffic workload already took the zero-constraint early return on
main. Its T0 count is not a candidate speedup.

## Slurm results

For the disabled-constraint fixture, Callgrind measured 1,897,719,601
reference instructions versus 25,462,724 candidate instructions (74.5293x),
with byte-identical output. The soft-only T4 fixture was unchanged at 1.0x,
also byte-identical. `results/tier-focus.csv` has the exact counts.
Callgrind profiles are gzip-compressed for storage except the two FST retry profiles, which the reconciliation helper reads directly. Decompress a `.callgrind.gz` file with `gzip -dc` before using Callgrind tools.

The 18-workload corpus had identical reference/candidate output on all rows.
The largest other-workload instruction increase was `classq` at 0.001328%.
The first candidate `waveform_fst` Callgrind run exited 139; a plain rerun and
an isolated Callgrind retry passed for both builds with identical output. The
initial failure remains in `corpus.json` and its Valgrind log; the validated
retry is preserved separately and used in `corpus-reconciled.json`.

The Caliptra fixed window (mcycle 100–2,100) had no `randomize()` calls in any
of the three tests. One sample per build produced a three-test geometric mean
of 1.0103x candidate/main; spread is not available from one sample. The
candidate therefore does not improve these Caliptra tests.

The final isolated wall-time job (3382) used three interleaved runs on one CPU
and the same pinned binaries. The 400-call T0 fixture measured 0.244439 s
reference median (7.968% spread) and 0.004073 s candidate median (0.422%
spread), or 60.021x, with byte-identical output. Wall time is supporting
evidence; the instruction screen is the gate. First attempt 3381 was discarded
because GNU `time %e` rounded the candidate to 0.00 s; the corrected rerun uses
a nanosecond monotonic timer. Both attempts are preserved.

The measurement job completed the profiles, histograms, and output comparisons
but exited 1 during checksum packaging because its original `sha256sum`
command included a directory. A corrected file-only manifest and
`validate_wp7_results.py` passed; see `results/validation.txt` and
`results/SHA256SUMS`. This is an evidence-packaging failure, not a simulation
or comparison failure.

No T1/T2 paths or T3 context reuse are implemented. The only seeded path change
is T0, and its 400-call stream is byte-identical. Slurm job 3379 passed make-check, FPGA install, the full ivtest gate (4,798 JSON
cases, zero failures), and real-DPI UVM (367 passed, zero failed or skipped).
Exact-head CI remains required before merge.
