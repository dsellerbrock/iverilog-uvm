# Clause 7.4–7.5 first array attempt

Slurm job 3222 ran against the pinned Icarus build from main
`c31cbf1b52f1a39d5775f276e2340525a444a79e`. It requested one CPU and 1 GiB;
each compiler and simulation command had a 120-second timeout. The complete
result archive was copied from DAN-DESKTOP and its SHA-256 verified.

## Results

- `p07_04_arrays.sv` failed to compile in both editions at its standard-valid
  unpacked-array equality expressions. Icarus reported “Array unpacked_b needs
  an array index here” and the same for `unpacked_a` (twice). Because the
  combined file did not compile, its packed-array indexing, packed part-select,
  unpacked whole-array copy, and runtime self-checks did not run; they are not
  classified from this attempt.
- `p07_04_unpacked_slice.sv` compiled and passed in both editions.
- `p07_05_dynamic_arrays.sv` compiled and passed in both editions, including
  allocation, size, `new[size](source)` initialization and default padding,
  and deletion.
- The batch ended with `OVERALL_RC=1` due to the equality compile failure. This
  is a standard-feature finding, not an infrastructure loss.

The exact subclause numbers differ between editions: packed/unpacked array
operations are IEEE 1800-2017 §7.4.3 and IEEE 1800-2023 §7.4.6; array slicing
is 2017 §7.4.6 and 2023 §7.4.5; dynamic-array allocation, size, and deletion
are §7.5.1–§7.5.3 in both editions.

## Reproduction and hashes

```text
Slurm job  3222
result archive  b3e7bbf1d4b24fea05d32edffcc1ca48d85d2a6fc7d08a699d017e336d237390
input/probes.tar.gz  55b870d18a8c7d26c4f2524e84c79c0aded66b9cd204b09c249e4bee9d828863
run.sbatch  92cfd2eaf2ee87b92cd28ebf1b5e8287a0cae32d6f216109367e95615cab5dee
```
