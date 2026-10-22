# IEEE 1800 §20.7 array-query probes

The probes ran on macOS ARM64 at commit `b9441bafbdb0b6b7413c09e0381845e69481391b`, using the Icarus/vvp hashes recorded in the attempt directory. Each compile and simulation ran sequentially under `~/codex-supervisor/localrun 10` in `-g2017` and `-g2023`. Per-command logs contain exit codes, wall time, and peak RSS; `summary.log`, source hashes, toolchain hashes, and host are recorded in `attempt-01-array-query/`.

The positive source has 16 named checks. It compiles and runs in both editions with `RESULT pass=10 fail=6`; failures are `dims_type`, `type_arg`, `int_types`, `assoc`, `assoc_empty`, and `multi`. The accepted results are otherwise identical between editions.

The first negative, `n20_07_dyn_dim_2.sv`, is an invalid reducer: it places a variable reference in a `localparam`, so the constant-expression diagnostic does not test the standard's dynamic-dimension restriction. It is discarded. The dynamic-array type query `n20_07_dyn_type.sv` and procedural `$size(a,2)` query `n20_07_multi_var_size.sv` compile successfully in both editions, but their run-time values have not been isolated.

The lead's value probe was first generated with an extra `$right(N)` display argument; that attempt is retained but invalid. A corrected copy in `attempt-03-values-corrected/` compiles in both editions, then exits with rc=1 before printing any `Q` lines. It emits four `$size` diagnostics on the multi-dimensional dynamic-array line (the `$size(a,1)` and `$size(a,3)` queries) and two diagnostics on the intended invalid `$size(a,2)` query.

Attempt 04 isolates 29 queries into one source each. The 2017 and 2023 outputs match. Passing expected values include `$size(Ram,2)=16`, `$size(Ram)=10`, integer variable bounds, byte/shortint bounds, and dynamic-array element sizes 4 and 0. Differences include `$dimensions(Word)=0` (expected 1), `$unpacked_dimensions(a)=1` (expected 3), `$size(Word)`, `$left(Word)`, `$right(Word)`, and `$left(int)` all yielding `x` instead of 16/16/1/31, and associative-array functions returning: left 0, right -1, low 0, high -1, increment 0, size 0 for three allocated keys; after deletion, low 0 and high -1 rather than `x`. `$size(a,1)` and `$size(a,3)` each produce runtime errors for a legal multidimensional dynamic array query. `$size(a,2)` also produces a runtime error for the standard-invalid dynamic dimension query. `$size(DT)` returns `x` with no error for a dynamic-array type identifier.

The audit lead classified the §20.7 results and filed [#792](https://github.com/dsellerbrock/iverilog-uvm/issues/792) (type-argument queries), [#793](https://github.com/dsellerbrock/iverilog-uvm/issues/793) (associative-array query values), and [#794](https://github.com/dsellerbrock/iverilog-uvm/issues/794) (legal queries on arrays with a dynamic dimension) after open/closed deduplication. The invalid `$size(a,2)` case errors at run time and is conforming in outcome, but the same error on legal dimensions is covered by #794. The dynamic-type `$size(DT)` case is covered by #792. Full per-file output, diagnostics, exit codes, wall time, and peak RSS are in `attempt-04-isolated/summary.log` and its individual logs.

## Fixture whitespace normalization

The `q_int_left.sv` fixture was normalized after the original probe in `attempt-04-isolated`; that historical record contains no Slurm job number because it was a local Mac run. Only trailing spaces and tabs were removed, so semantics are unchanged. On 2026-10-21, it was recompiled and rerun in both editions under the same `localrun 120` invocation and pinned Icarus/VVP hashes. Both outputs (`Q int_left=x exp 31`) match the prior records; the per-case log is `attempt-04-isolated/whitespace-recheck-20261021.log`.

Post-normalization SHA-256 (trailing spaces and tabs removed):

| Original SHA-256 | Post-normalization SHA-256 | Fixture |
|---|---|---|
| `d21f37dd2cacf17ad25fd30627c844790cf4b4d21261d0355841c97e361f328b` | `28eedf1893d4a76047e89c1393fdc956087ab6c32404d5bc9973f03b7ce3ff05` | `tests/1800_audit/c20/q/q_int_left.sv` |
