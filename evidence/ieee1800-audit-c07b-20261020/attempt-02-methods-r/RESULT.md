# §7.12 remaining method checks (Slurm job 3513)

- Host: DAN-DESKTOP; 1 CPU, 1 GiB; each compile/run had a 30-second timeout.
- Compiler: Icarus 13.0-devel `cc25756d1`; `iverilog` SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Both editions compile and run `p07_12_methods_r.sv` with rc 0; stdout matches the expected file exactly. `n07_12_shuffle_with.sv` also compiles with rc 0 and no diagnostic in both editions, though IEEE 1800 §7.12.2 requires a compiler error for `shuffle() with`.

```text
L1 7 7 9
L2 1 3
L3 7
L3I 1
L4 2
L4I 2
L5 2
L5X 9
L6 4 22
L8 0
I1 4 7 7 9
O1 2 4 7 7 9
O2 9 7 7 4 2
O3 9 7 2 7 4
O4 5 29
O5 0 2
R1 10
R2 24
R3 12
R5 44
R6 300
```

The §7.12.3 result-type rule was checked directly in both editions. Exact sentence: “The method returns a single value of the same type as the array element type or, if specified, the type of the expression in the with clause.” (2017 §7.12.3, p.168; 2023 §7.12.3, p.176.) Therefore `w.sum` returns the array element type `bit [7:0]` and wraps 300 to 44; `w.sum with (int'(item))` has an `int` result and returns 300.

The previous run's 2-D example `m.sum with (item.sum with (item))` is rejected as recorded in `attempt-01-array-methods/RESULT.md`; it is the standard's nested §7.12.3 example and is tracked by #851. `reverse() with` was also accepted in that run. This run confirms `shuffle() with` is accepted too; both are tracked by #852. The two issue rows were created in the matrix. No other runtime mismatch was observed.

Warnings: none in compile or simulation stderr for the methods run; the `shuffle() with` compile produced no diagnostics.

Raw output: `results-3513.tar.gz`; source/tool hashes: `results/SHA256SUMS`; source diff is `methods-r-only.diff`.
