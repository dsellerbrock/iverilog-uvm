# Caliptra fixed-window VVP profile

Both runs use Caliptra RTL `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`, QD-BFM `8e34e0c6d20b6f84a5a975ba6e3de7ccd9b1dc2b`, case `cptra_ss_test_rom`, and the same VPI mcycle window (cycles 100–600, 500 cycles). The optimized build is `c014c0a7975a4b0b645ea34609c802be60a10f4a` plus the local #536 diff.

| Build | Elapsed | Effective rate | `of_PROP_INDEX_CHECK` profile share |
|---|---:|---:|---:|
| c014 baseline | 64.305 s | 7.775 cycles/s | 8.33% |
| c014 + #536 | 59.372 s | 8.422 cycles/s | 5.87% |

The fixed window improved by 8.31%; the profiled share of the optimized property-index handler fell by 2.46 percentage points. Both simulator processes exited 0, but the firmware runner marks each partial fixed-window run `passed: false` because the simulation is deliberately stopped before any testcase pass/finish marker. This is performance evidence for the same bounded trace segment, not a completed firmware-test pass.

Raw reports, `perf.data`, tool hashes, resource records, and runner result JSON are in `baseline-c014/` and `optimized-c014/`.
