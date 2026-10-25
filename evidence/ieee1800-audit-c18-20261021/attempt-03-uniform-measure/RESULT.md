# Paired-edition uniformity measurement

## Provenance

- Host: DAN-DESKTOP, Slurm job 3721; 1 CPU, 128 MiB, 6-minute limit; each compile and simulation had a 120-second timeout.
- Toolchain: Icarus 13.0-devel at `/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb`, commit `cc25756d`; `iverilog` SHA-256 `87bb417df23d260bcfde3fb372b4a80eaad69e4fd2eea1ffb8b0eff10f7af08e`, `vvp` SHA-256 `dfc193c466a70a0917a16ab4198a111de616657d6004de79456db2a4b603b437`.
- Source was staged from branch `m7-1800-audit-c08`, HEAD `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; source and script hashes are in `INPUT-SHA256SUMS.txt`.
- Both editions compiled and ran without timeout. Full compile/run logs and `slurm-3721.out` are preserved in this directory.

## Results

The 5σ windows below are those provided by the audit lead for `n=2000`:

| Measure | Expected | 5σ window | `-g2017` | `-g2023` |
|---|---:|---:|---:|---:|
| Mean `a` | 63.25 | 57.75–68.75 | 62.93 | 62.93 |
| Mean `b` | 127.5 | 122.0–133.0 | 125.85 | 125.85 |
| Mean `c` | 191.75 | 186.25–197.25 | 190.87 | 190.87 |
| Count `a < 32` | 662 | 557–767 | 670 | 670 |

Neither edition emitted the “too large to enumerate” warning at compile time or during simulation. Both runs took 2.77 seconds (`-g2017`) and 2.74 seconds (`-g2023`), about 1.385 ms and 1.370 ms per `randomize()` call; peak RSS was 40,948 and 41,088 KiB. All four statistics are inside their 5σ windows, so this flat increasing-triple sample did not detect a distribution bias. It does not refute the warning and non-uniformity evidence for the separate 8-bit heap probe already in #843.
