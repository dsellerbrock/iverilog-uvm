# End-to-end Caliptra throughput: campaign base, M2 main, and current main

Each sample covers 2,000 mcycles (100–2,100) in the full Caliptra top-level testbench. Three repeats per test and build were interleaved on one Slurm CPU. Spread is (maximum minus minimum) divided by median.

| Test | Campaign base f9f8e0a | M2 main 9b5fad2 | Current main 8c95b5c | Current vs campaign base | Current vs M2 main |
|---|---:|---:|---:|---:|---:|
| smoke_test_dma_aes_gcm_short_1_dword | 7.821 (1.87%) | 9.915 (2.34%) | 9.913 (2.05%) | +26.74% | -0.02% |
| smoke_test_sha256 | 7.746 (2.23%) | 9.778 (1.93%) | 9.941 (3.12%) | +28.33% | +1.67% |
| cptra_ss_test_rom | 7.718 (8.40%) | 9.789 (4.05%) | 9.914 (12.89%) | +28.46% | +1.28% |

Three-test geometric-mean m2 main vs base: +26.60%.

Three-test geometric-mean current main vs base: +27.84%.

Three-test geometric-mean current main vs m2 main: +0.97%.

All 39 generated firmware hex inputs matched across every repeat and build. Normalized simulator logs matched after removing only the mcycle-window marker and progress-heartbeat lines. VPI deliberately stops each incomplete test at mcycle 2,100; the expected runner exit is 1, so these are bounded throughput samples, not firmware pass results.
