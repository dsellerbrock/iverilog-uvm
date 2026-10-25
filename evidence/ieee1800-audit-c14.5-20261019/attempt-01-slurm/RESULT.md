# Clause 14.5 audit — Slurm job 3162

- Standard scope: IEEE 1800-2017 §14.5, p. 340; IEEE 1800-2023 §14.5, p. 358.
- Clean source: `origin/main` at `c31cbf1b52f1a39d5775f276e2340525a444a79e`.
- Host: DAN-DESKTOP; 2 CPUs / 3 GiB requested; build wall time 3:14.06; build peak RSS 1,663,568 KiB.
- Icarus SHA-256: `2b592ae9d59bf23e83431b4d129d4f95b6d05bb2962d5766bd42d039db15269b`; VVP SHA-256: `2ad4a1d846e775c44d6443033fd2855fe82c3c685a80c3ee9bf3b38686eb7d4a`.
- The probe matrix matched 6 of 8 expectations. Positive cases passed in both editions; the invalid output-expression case was accepted in both.
- Raw compiler/runtime outputs and logs are saved under `results/` and `logs/`. Local `RAW-SHA256SUMS` and input checksums validate.
- After recording the result, removed only this run's remote `source/`, `install/`, and `input/` trees. Freed 1,629,958,220 bytes (1.63 GB / 1.52 GiB); remote `results/` and `logs/` remain.

## Results

- `p14_05_hier_ref`, `p14_05_slice`, and `p14_05_concat`: compile and run successfully with `-g2017` and `-g2023` (6/6).
- `n14_05_illegal_output_expr`: expected compile rejection, but compilation succeeds and writes a `.vvp` in both editions. The only diagnostic says the `out` expression is not a resolvable signal path and the clockvar is not sampled.

IEEE 1800-2017/2023 §14.5 requires a clocking output expression to be legal for a module output-port connection. Since `a + b` is accepted instead of rejected, the tested implementation is **PARTIAL**. The verified gap is tracked by [#702](https://github.com/dsellerbrock/iverilog-uvm/issues/702).
