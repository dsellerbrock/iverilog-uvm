# WP0 full-gate evidence

The tested source snapshot is `430d95aabd93b9922f5987b108bf27de894aed1d`,
rebased onto current `origin/main` (`3335fe7ec1495956c8adc5788e9a53b0f1756ecf`).
The source and UVM submodule archive hashes are in `source-manifest.txt`.
The inherited WP0 reference `vvp/` source is unchanged between the reference
baseline and current main.

## Attempts

| Job | Outcome |
| --- | --- |
| 1011 | Setup failure before source extraction: the archive checksum list was checked from the wrong working directory. No build or test ran. Details are in `attempts/job1011/`. |
| 1012 | From 430d95aabd on base 3335fe7, both builds and the stats symbol/smoke checks passed; make check, the legacy/negative/VPI gate, and FPGA install passed. Full JSON ivtest ran 4,630 tests and returned 16 gold/compile mismatches. All 16 selectors are preserved in the current-main baseline comparison (attempts/baseline-json-33bb0fa/attempt-status.txt) and reproduce on origin/main 33bb0fa. The UVM stage was not reached. Because #581 advanced main during this run, WP0 must be rebased and the full gates rerun before delivery. |
