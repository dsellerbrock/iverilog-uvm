# M3 Caliptra throughput remeasurement, `8c95b5c`

Pinned campaign base: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`. The comparison builds are matched M2 main `9b5fad2afb4104caa816b257d5bccc40f01b8c66` and current main `8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1`.

Slurm job 3275 completed successfully on DAN-DESKTOP in 2h13m. It ran three interleaved repeats per revision and test, with each run pinned to CPU 17 and covering exactly mcycle 100–2,100 (2,000 mcycles). The expected runner exit is 1 because the VPI window stops each incomplete firmware test at mcycle 2,100; the batch job exit was 0. All 27 windows completed.

| Test | Campaign base median (spread) | M2 main median (spread) | Current main median (spread) | Current vs base | Current vs M2 |
|---|---:|---:|---:|---:|---:|
| `smoke_test_dma_aes_gcm_short_1_dword` | 7.821 (1.87%) | 9.915 (2.34%) | 9.913 (2.05%) | +26.74% | -0.02% |
| `smoke_test_sha256` | 7.746 (2.23%) | 9.778 (1.93%) | 9.941 (3.12%) | +28.33% | +1.67% |
| `cptra_ss_test_rom` | 7.718 (8.40%) | 9.789 (4.05%) | 9.914 (12.89%) | +28.46% | +1.28% |

Cycles/second medians and spreads are calculated from the three per-run `elapsed_ns` values; spread is (max − min) / median. The three-test geometric-mean gain is +27.84% over campaign base and +0.97% over matched M2 main. The ROM result is 9.914 cycles/s, below the requested 13.3 cycles/s goal. The prior 10.608 result used a 500-mcycle window; the comparable 2,000-mcycle M2 ROM median here is 9.789 cycles/s, so current main is +1.28% on the matched window. The widest spread is the ROM's 12.89%; per instruction, it is reported as supporting evidence and does not gate the instruction-count screens.

Across all 39 generated firmware hex inputs, every revision and repeat matched. Normalized simulator logs also matched after removing only the mcycle-window marker and progress-heartbeat lines. The archive omits raw logs because they print test key material; it includes the 27 normalized-log SHA-256 digests in `results/normalized-log-sha256.tsv` instead.

The job archive is [`job-3275-results-8c95b5c.tgz`](attempts/job-3275-results/job-3275-results-8c95b5c.tgz), SHA-256 `835b96b356f99481d00fabbd735b13012504fdfae7e1f823f96d1720017dfd5f`. The job's initial summary had a stale hard-coded `cae0356` revision label; the raw timing/input artifacts are preserved unchanged, and the corrected analysis in [`analysis/`](analysis/) was rerun against all 27 archived windows and verifies the input/log digest equality assertions.
