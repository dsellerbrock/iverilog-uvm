# End-to-end Caliptra top-level throughput

Each sample covers the same 2,000 mcycle interval (100–2,100) in the full Caliptra top-level testbench. Runs were interleaved, one process at a time, pinned to one Slurm CPU. Spread is (max - min) / median.

| Test | Build | Median cycles/s | Min–max | Spread |
|---|---|---:|---:|---:|
| smoke_test_dma_aes_gcm_short_1_dword | base | 7.436 | 6.982–7.813 | 11.17% |
| smoke_test_dma_aes_gcm_short_1_dword | main | 8.211 | 7.976–9.573 | 19.45% |
| | main vs base | | | +10.43% |
| smoke_test_sha256 | base | 7.544 | 6.987–7.833 | 11.21% |
| smoke_test_sha256 | main | 8.844 | 7.757–9.680 | 21.74% |
| | main vs base | | | +17.24% |
| cptra_ss_test_rom | base | 7.762 | 7.346–7.912 | 7.29% |
| cptra_ss_test_rom | main | 8.194 | 8.151–9.061 | 11.10% |
| | main vs base | | | +5.57% |

Geometric-mean cumulative speedup across the three tests: +10.98%.
Equal-window pooled throughput: 7.578 → 8.406 cycles/s (+10.92%).

The timing marker intentionally stops the simulation before testcase completion; these are fixed-window throughput measurements, not firmware pass results.
The generated firmware .hex inputs and simulator output logs matched across builds.
