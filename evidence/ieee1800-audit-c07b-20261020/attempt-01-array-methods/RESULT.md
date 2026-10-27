# §7.12 array manipulation method initial probe (Slurm job 3512)

- Host: DAN-DESKTOP; 1 CPU, 1 GiB; each compile/run had a 30-second timeout.
- Toolchain: Icarus 13.0-devel `cc25756d1`; executable and source hashes are in `results/SHA256SUMS`.
- Both editions were tested.

| Case | 2017 | 2023 | Observation |
|---|---|---|---|
| `p07_12_methods.sv` | compile rc 1 | compile rc 1 | no runtime; both editions report line 24: `error: Array reduction method sum() requires a one-dimensional unpacked array; got 2 unpacked dimensions.` This line is the IEEE-standard nested array reduction example `m.sum with (item.sum with (item))` from §7.12.3. |
| `n07_12_reverse_with.sv` | compile rc 0 | compile rc 0 | accepted with no diagnostic; not run. |

IEEE 1800-2017 and 1800-2023 §7.12.2 state that specifying a `with` clause on `reverse()` shall be a compiler error. The accepted negative is therefore a candidate gap. Since the positive file did not compile, no locator, ordering, iterator-index, or other reduction runtime results were collected in this attempt.

Dedupe searches from the initial scope are in `dedupe-open-closed.txt`; no issue has been filed from this attempt. The open audit count remains 115 (2 in §7).

Raw data: `results-3512.tar.gz`; copied source snapshot: `input.tar.gz`; compile diagnostics, source hashes, timings and scheduler output are preserved in `results/` and `logs/`.
