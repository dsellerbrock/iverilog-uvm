# Clause 7.4–7.5 corrected array probes

Slurm job 3223 ran against the pinned Icarus 13.0 development build from main
`c31cbf1b52f1a39d5775f276e2340525a444a79e` (iverilog SHA-256
`f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; VVP
SHA-256 `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`).
The Slurm request was one CPU and 1 GiB; each compile and simulation had a
120-second timeout. All probes below passed and the script reported
`OVERALL_RC=0`.

## Results

- IEEE 1800-2017 and 1800-2023: multidimensional packed indexing, nested
  packed selects, `+:` part-select, multidimensional unpacked indexing,
  whole-array copy, and element-wise copy independence passed.
- Both editions: one-dimensional unpacked-array equality and inequality pass.
- Both editions: assignment from an unpacked array slice passes. The relevant
  clause is 2017 §7.4.6 and 2023 §7.4.5.
- Both editions: dynamic-array `new[size]`, `size()`, `new[size](source)` copy
  with default padding, and `delete()` pass (§7.5.1–§7.5.3).

The first attempt (attempt-02) found that the same array equality operators on
two-dimensional unpacked arrays fail to compile. That behavior is kept as a
separate candidate gap; the passing one-dimensional case does not cover it.

## Probe files

- `tests/1800_audit/c07/p07_04_arrays.sv`
- `tests/1800_audit/c07/p07_04_unpacked_slice.sv`
- `tests/1800_audit/c07/p07_04_unpacked_array_equality.sv`
- `tests/1800_audit/c07/p07_05_dynamic_arrays.sv`

## Reproduction and hashes

```text
Slurm job  3223
results-3223.tar.gz  068cf9ec13131ee0516d5f979ebe397bb86da91a0f92602494430359a17fd076
input/probes.tar.gz  3f25cf4ed3adc7ebee494170b59c7e42031792163343a5c2dd6a645350ab6a93
run.sbatch  cb4b36b7f187d45143fb81556899eb56a8e29d4ae080b877ea0ad7845251ca33
```
