# Isolated array-query results

- Simulator source commit: `cc25756d187314742d347267c2a513b3e640a7fb`
- Slurm job: `3524` (`1` CPU, `1G`, five-minute limit; completed)
- Toolchain: Icarus 13.0-devel (`cc25756d1`); `iverilog` SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`, `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`
- Every compile and simulation had an individual 30-second timeout. The exact commands, statuses, and source hashes are in [`slurm-3524.out`](slurm-3524.out); raw per-case output is in [`results/`](results/).

## Results in both editions

- q1 (`p07_11_query.sv`): all expected values pass. Lines are `D 2 0 3 2`, `U1 2 5 2 5 -1 4`, `U2 0 1 -1 2`, `P 3 1 4 8`, `Y 3 0 2 1`; the invalid-dimension query returns 32 X bits.
- q2 (`p07_11_query_assoc.sv`): prints `A 0 -1 0 -1 0 0 00000000000000000000000000000000`; expected `0 2147483647 5 9 -1 2` and 32 X bits. This reproduces #793.
- q3 (`p07_11_query_runtime_type.sv`): prints `R x 16`, reproducing the `$size(Word)` type-argument value in #792; the variable query `$size(Ram,2)` returns 16.
- q4a (`p07_11_const_size_type.sv`): compiles/runs but prints `ST 0`, also overlapping #792.
- q4b (`p07_11_const_size_ram.sv`): compilation fails with `A reference to a net or variable (Ram) is not allowed in a constant expression`, despite the standard example permitting it. Filed as [#855](https://github.com/dsellerbrock/iverilog-uvm/issues/855).
- q5 (`p07_11_query_var_dimension.sv`): compilation succeeds, but simulation returns 1 and reports that `$size` arguments must be dynamic arrays/queues/strings and have too many arguments. This reproduces #794's failures on legal queries.
- n1 (`n07_11_nonintegral_assoc_query.sv`): compiles and runs with exit code 0, prints `0`, and gives no diagnostic. This silently accepts `$size` on a string-keyed associative array, which §20.7 restricts to integral key types. Filed as [#856](https://github.com/dsellerbrock/iverilog-uvm/issues/856).
- n2 (`n07_11_dynamic_dimension_query.sv`): compilation succeeds; simulation returns 1 with a `$size` runtime error for querying variable dimension 2. This is the standard-prescribed error and matches the existing #794 case.

All results were identical under `-g2017` and `-g2023`. Follow-up comments were posted on existing issues [#792](https://github.com/dsellerbrock/iverilog-uvm/issues/792), [#793](https://github.com/dsellerbrock/iverilog-uvm/issues/793), and [#794](https://github.com/dsellerbrock/iverilog-uvm/issues/794); exact comment bodies are saved in `comments/`.
