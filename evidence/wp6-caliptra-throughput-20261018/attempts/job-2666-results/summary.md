# End-to-end Caliptra throughput: campaign base, main, and WP6 #658

Each sample covers 2,000 mcycles (100–2,100) in the full Caliptra top-level testbench. Three repeats per test and build were interleaved on one Slurm CPU. Spread is (maximum minus minimum) divided by median.

| Test | Campaign base f9f8e0a | Main d9caaae | WP6 candidate 3b9101a | Candidate vs base | Candidate vs main |
|---|---:|---:|---:|---:|---:|
| smoke_test_dma_aes_gcm_short_1_dword | 8.355 (3.45%) | 10.779 (5.75%) | 10.782 (5.48%) | +29.05% | +0.03% |
| smoke_test_sha256 | 8.272 (6.46%) | 10.376 (2.66%) | 10.660 (1.96%) | +28.87% | +2.73% |
| cptra_ss_test_rom | 8.250 (7.58%) | 10.450 (3.17%) | 10.114 (14.69%) | +22.58% | -3.22% |

Three-test geometric-mean main vs base: +27.03%.

Three-test geometric-mean candidate vs base: +26.80%.

Three-test geometric-mean candidate vs main: -0.18%.

All 39 generated firmware hex inputs matched across every repeat and build. Normalized simulator logs matched after removing only the mcycle-window marker and progress-heartbeat lines. VPI deliberately stops each incomplete test at mcycle 2,100; the expected runner exit is 1, so these are bounded throughput samples, not firmware pass results.
