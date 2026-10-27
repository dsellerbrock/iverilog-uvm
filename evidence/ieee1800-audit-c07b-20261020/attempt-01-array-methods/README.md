# IEEE 1800 §7.12 array manipulation methods

The positive probe covers §7.12.1 locators, §7.12.2 ordering, §7.12.3 reductions, and §7.12.4 iterator indices. The negative source checks the normative §7.12.2 rule that a `with` clause on `reverse()` (and likewise `shuffle()`) is a compiler error. Direct text was checked in 1800-2017 pp.165–168 and 1800-2023 pp.174–177. In particular, §7.12.3 says the reduction result type/width is the array element type unless `with` supplies the result expression type.

Expected outputs, including the trailing separator from `qs()`, are stored in `input/expected.txt`. Each compile/run has a 30-second timeout. Slurm resources: 1 CPU, 1 GiB, 20 minutes. All diagnostics and raw stdout/stderr are preserved.

## Archive integrity

- `input.tar.gz`: 1501 bytes; SHA-256 `4af5f32b70d3387a434a771cd108b67a44319e52f6058aa08780ccdb795d01c9`.
- `results-3512.tar.gz`: 2484 bytes; SHA-256 `9f1dcb00c8c65a5cc86e9fdc7b3a975642687020031440a477ca5e90df1f4929`.
