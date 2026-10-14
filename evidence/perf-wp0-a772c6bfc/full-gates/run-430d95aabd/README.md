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
| 1012 | Full gates are running from a fresh directory with checksum verification and in-tree configure fixes. Results will be added after completion. |
