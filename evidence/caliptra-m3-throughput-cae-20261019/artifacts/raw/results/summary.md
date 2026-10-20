# End-to-end Caliptra throughput: campaign base, M2 main, and current main

Each sample covers 2,000 mcycles (100–2,100) in the full Caliptra top-level testbench. Three repeats per test and build were interleaved on one Slurm CPU. Spread is (maximum minus minimum) divided by median.

| Test | Campaign base f9f8e0a | M2 main 9b5fad2 | Current main cae0356 | Current vs campaign base | Current vs M2 main |
|---|---:|---:|---:|---:|---:|
| smoke_test_dma_aes_gcm_short_1_dword | 7.827 (8.38%) | 9.769 (12.96%) | 9.949 (16.91%) | +27.11% | +1.84% |
| smoke_test_sha256 | 7.479 (18.22%) | 10.010 (14.46%) | 10.255 (12.53%) | +37.11% | +2.44% |
| cptra_ss_test_rom | 7.794 (15.41%) | 9.717 (18.98%) | 9.751 (13.00%) | +25.10% | +0.35% |

Three-test geometric-mean m2 main vs base: +27.70%.

Three-test geometric-mean current main vs base: +29.67%.

Three-test geometric-mean current main vs m2 main: +1.54%.

All 39 generated firmware hex inputs matched across every repeat and build. Normalized simulator logs matched after removing only the mcycle-window marker and progress-heartbeat lines. VPI deliberately stops each incomplete test at mcycle 2,100; the expected runner exit is 1, so these are bounded throughput samples, not firmware pass results.
