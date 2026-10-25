# Warned-heap uniformity measurement

## Provenance

- Host: DAN-DESKTOP. Initial job 3727 used 1 CPU, 128 MiB, and 300-second per-edition run timeouts. Fallback job 3729 used the same resources and limits with `n=1000`.
- Toolchain: Icarus 13.0-devel at `/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb`, commit `cc25756d`; `iverilog` SHA-256 `87bb417df23d260bcfde3fb372b4a80eaad69e4fd2eea1ffb8b0eff10f7af08e`, `vvp` SHA-256 `dfc193c466a70a0917a16ab4198a111de616657d6004de79456db2a4b603b437`.
- The original `n=2000` source is preserved as `p18_uniform_heap_n2000.sv`; the final test source `tests/1800_audit/c18/p18_uniform_heap.sv` uses `n=1000`. All source and script hashes are in `INPUT-SHA256SUMS.txt`.
- Full attempt logs are in `results-n2000/`, `results-n1000/`, `slurm-3727.out`, and `slurm-3729.out`.

## Attempt 1: `n=2000`

The compiler completed under both editions. Both simulation logs emitted the required warning: “a joint randomization component is too large to enumerate exactly; it is sampled against the hard constraints, not uniformly over its solutions.” Each run hit its 300-second timeout before printing a sample summary: `-g2017` 300.14 seconds, peak RSS 41,900 KiB; `-g2023` 300.12 seconds, peak RSS 41,748 KiB. This is a time-limit result, not an infrastructure failure.

## Attempt 2: `n=1000`

Both editions emitted the required fallback warning and completed without timeout:

| Measure | Expected | 5σ window after √2 widening | `-g2017` | `-g2023` |
|---|---:|---:|---:|---:|
| Mean `left.v` | 63.5 | 53.6–73.4 | 129.46 | 129.46 |
| Mean `v` | 127.0 | 117.1–136.9 | 190.79 | 190.79 |
| Mean `right.v` | 191.5 | 181.6–201.4 | 222.21 | 222.21 |
| Count `v<32` | 44.25 | approximately −20.9–109.4 | 6 | 6 |

All three means are far outside their widened 5σ windows; the count is inside its broad window. The measured values are identical in both editions. Simulation time was 212.78 seconds (`-g2017`) and 212.07 seconds (`-g2023`), about 212.8 ms and 212.1 ms per `randomize()` call; peak RSS was 41,784 and 41,964 KiB.

The warned fallback produces a strongly non-uniform distribution on the standard's heap example, confirming the #843 gap in both editions.
