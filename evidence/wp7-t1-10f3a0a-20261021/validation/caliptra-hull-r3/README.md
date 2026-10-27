# Caliptra bounded-window follow-up, job 3841

Pinned measurement base: `10f3a0a2509d0852c2556cb6622fb0025121fb2d`.
Candidate: `2a2e71b3a04888dc6a8c848be8f5b20a6be8bdd7`.
The reference and candidate used the same frozen binaries from job 3820, the
same Caliptra RTL pin, QD-BFM source directory pin
`d1529c922da402943148a0fb22648f347e30eed9`, and CPU 0. Each case ran only
cycles 100 through 2,100 (2,000 mcycles).

| Test | Reference cycles/s | Candidate cycles/s | Single-pair change | Randomize calls |
|---|---:|---:|---:|---:|
| `smoke_test_dma_aes_gcm_short_1_dword` | 6.072352 | 6.099635 | +0.449% | 0 / 0 |
| `smoke_test_sha256` | 6.151785 | 5.968772 | -2.975% | 0 / 0 |
| `cptra_ss_test_rom` | 5.988663 | 5.919707 | -1.151% | 0 / 0 |

The QD-BFM pin comes from the immutable directory name; its source directory
has no Git metadata, so the raw provenance file's `qd_bfm` field is blank.

These are one reference-then-candidate pair per test, not medians. All three
normalized 2,000-mcycle prefixes and generated firmware hash lists match
byte-for-byte.
Normalization removes only `VVP_PERF_STATS`, progress heartbeat, and
`MCYCLE_WINDOW` lines. Each runner's `result.json` has `sim_exit=0`, zero
failure markers, and `passed=false` because the bounded prefix does not reach
a top-level completion marker. This is prefix-equivalence evidence, not a
full functional test pass. Job 3809 contains the completed full-run evidence
and also records zero randomize calls for these three Caliptra tests.

Job 3841's post-run analyzer exited 1 on the unfiltered progress and elapsed
lines. The local analysis reran the intended comparisons with those
nondeterministic instrumentation lines removed. See `analysis/` for the
summary, histogram, and derived checksums. `artifacts/job-3841/local-SHA256SUMS`
checks the fetched runner logs, result JSON, resource reports, and firmware
hash lists. Full simulator transcripts remain local because they print
cryptographic test-vector material. The analysis JSON records each
normalized-prefix hash.
