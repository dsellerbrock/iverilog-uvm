# Isolated IEEE 1800 §20.7 query probes

Each query family runs in its own top-level module so a runtime error in one feature does not hide output from another. All probes run under `-g2017` and `-g2023` with 30-second compile/run timeouts.

| Probe | Coverage | Expected |
|---|---|---|
| `p07_11_query.sv` | D, U1, U2, P, Y, X: dimension counts, bounds, increment, size, packed/unpacked, dynamic/queue, and out-of-range query | `2 0 3 2`; `2 5 2 5 -1 4`; `0 1 -1 2`; `3 1 4 8`; `3 0 2 1`; all X bits |
| `p07_11_query_assoc.sv` | A: valid integral-key associative-array query values, including empty low bound | `0 2147483647 5 9 -1 2` followed by all X bits |
| `p07_11_query_runtime_type.sv` | Q3: `$size(Word)` and `$size(Ram,2)` at run time | `16 16` |
| `p07_11_const_size_type.sv` | Q4a: `$size(Word)` in a localparam | `16` |
| `p07_11_const_size_ram.sv` | Q4b: `$size(Ram,2)` in a localparam | `16` |
| `p07_11_query_var_dimension.sv` | Q5: legal §20.7.1 queries on an array with a variable dimension | `3 3 4 0 5` |
| `n07_11_nonintegral_assoc_query.sv` | n1: `$size` of a string-keyed associative array | An error; either compile or run stage may report it |
| `n07_11_dynamic_dimension_query.sv` | n2: `$size(a,2)` where dimension 2 is variable-sized | An error; either compile or run stage may report it |

The initial combined attempt and its corrective split are preserved separately: [`attempt-01-query/`](../attempt-01-query/). Standards citations and issue scopes are in [`STANDARD.md`](STANDARD.md) and [`DEDUPE.md`](DEDUPE.md). Actual results from Slurm job 3524 are in [`RESULT.md`](RESULT.md); each compile/run log is under [`results/`](results/).
