# #728 assignment-pattern equality follow-up

Date: 2026-10-27. Host: MacBook-Air.

Both compilers are built from clean base commit `02ff25587ad369ea333c61fee650a7e33c4fdeca`: the baseline binary is `/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-svtests-qualified-if-20260813/local-install/bin/iverilog`; the current #728 binary is `/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-m9-p1-1036-20261026/local-install-p1/bin/iverilog`. Runtime binaries are in the matching `bin/vvp` directories. The current worktree has staged #728 changes.

Commands used `~/codex-supervisor/localrun 180 bash <probe-script>`; each compiler invocation used `scripts/run_with_timeout.py 120`.

In both `-g2017` and `-g2023`, the current build rejects typed fixed-array assignment-pattern casts in `==`, `!=`, `===`, `!==`, plus a multidimensional typed pattern. It produces 9 elaboration errors for the nine typed expressions. The clean base rejects the same nine; the one-dimensional forms report the generic compatible-array diagnostic, while the multidimensional forms report `Array M needs an array index here`. Both compilers reject untyped `A=='{1,2}` with exactly one elaboration error. This confirms the typed-cast limitation predates #728. The separate untyped rejection is required because IEEE 1800-2023 §§10.8-10.9 do not provide an assignment-like context for a binary equality operand.

The packed-type reducer passes in both editions: same-width, same-state, same-signedness packed structs compare equal to packed vectors under §6.22.2(c)/§11.4.5; mismatch returns 0; X equality returns X while case equality returns 1; a 2-state packed struct compares equal to a matching 2-state vector.

The broader edge reducer also passes X/Z aggregation, rank-3 and per-dimension direction handling, size/typedef equivalence, net/struct/class-property/function-return arrays, real/string/class-handle elements, continuous/always sensitivity, and shape mismatch diagnostics. Dynamic/fixed operands reject with a diagnostic. The untyped assignment-pattern diagnostic wording is provisional and should not be treated as the required diagnostic text.
