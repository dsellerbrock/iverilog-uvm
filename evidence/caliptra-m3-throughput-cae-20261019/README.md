# End-to-end Caliptra throughput, M3 current main

Measurement reference pin: M2 main `9b5fad2afb4104caa816b257d5bccc40f01b8c66`, the 10.608 cycles/s ROM result. Candidate/current-main pin: `cae035642e056644274a01e98d4422ce286685b4`. Campaign base `f9f8e0a79f230f38da6cbb4445994ad1075ad531` is included as a cumulative reference.

The job follows the established job-2018 protocol: the same three Caliptra top-level tests, 2,000 mcycles per sample (100–2,100), three interleaved repeats per build, one pinned CPU, fixed Caliptra/RTL/QD-BFM/DPI inputs, and normalized simulator-log plus firmware-input equality checks. All three Icarus revisions are built in the isolated Slurm run directory with matching flags.

The exact commit pins, job script, runner, deterministic ECC source, mcycle VPI plug-in, analyzer, and raw run artifacts are preserved here. The M2 baseline is remeasured over the same 2,000-mcycle windows as current main; its earlier 10.608 cycles/s result used a shorter 500-mcycle ROM window and remains a separate anchor.

## Slurm job 3012

The job completed successfully on CPU 14. It covered 2,000 mcycles per sample
for all 27 runs. The expected VPI exit was 1 because each bounded run stops the
incomplete firmware test at mcycle 2,100. All 39 generated firmware hex inputs
matched across repeats and builds, and normalized simulator logs matched after
removing only the mcycle-window marker and progress-heartbeat lines.

Median cycles/s and `(max - min) / median` spread:

| Test | Campaign base `f9f8e0a` | M2 main `9b5fad2` | Current main `cae0356` | Current vs base | Current vs M2 |
|---|---:|---:|---:|---:|---:|
| DMA AES-GCM | 7.827 (8.38%) | 9.769 (12.96%) | 9.949 (16.91%) | +27.11% | +1.84% |
| SHA-256 | 7.479 (18.22%) | 10.010 (14.46%) | 10.255 (12.53%) | +37.11% | +2.44% |
| ROM | 7.794 (15.41%) | 9.717 (18.98%) | 9.751 (13.00%) | +25.10% | +0.35% |

The three-test geometric-mean speedup is +29.67% over the campaign base and
only +1.54% over the matched M2 main. The user target of 13.3 cycles/s is not
met. The 10.608 cycles/s M2 ROM anchor came from a 500-mcycle window, so it is
not directly comparable; using the matched 2,000-mcycle M2 ROM median gives a
12.146 cycles/s equivalent +25% target, versus 9.751 cycles/s on current main.
The cycle-rate spreads are high (up to 18.98%), and are reported as supporting
evidence rather than used to discard this fixed-window result.

The compressed raw archive is
[`artifacts/threeway-artifacts.tgz`](artifacts/threeway-artifacts.tgz),
SHA-256 `c501b9300d65ff03c0e21344f4eef2ac1b2188c1007b086584eaa2cee2f4ba4b`.
Its extracted `results/summary.json` and `results/summary.md`, all 27 per-run
windows/logs/input hashes, build logs, and job output are under
[`artifacts/raw/`](artifacts/raw/). The local three-way analyzer was rerun on
the extracted records and reproduced the saved summary exactly.
