# §18.4 and iterative-constraint nested-array boundary

IEEE 1800-2017/2023 §18.4 allows a rand unpacked structure’s random members to be solved with the containing class. The dynamic-array size rule applies to rand dynamic arrays. Iterative constraints are §18.5.8.1 in 2017 and §18.5.7.1 in 2023.

## Paired results

The ordinary class-member control [`p18_04_plain_darray_sizes_foreach.sv`](input/p18_04_plain_darray_sizes_foreach.sv) constrains a two-dimensional dynamic array to row sizes 1 and 2 and uses `foreach` to constrain its leaves. Both editions compiled and ran successfully, printing `PASSED`.

The reduced rand-struct size probe [`p18_04_struct_size_constraint.sv`](input/p18_04_struct_size_constraint.sv) was rejected at `record.values.size` in both editions with an unsupported unpacked-struct constraint-path diagnostic (compiler exit 1).

The pre-sized rand-struct foreach probe [`p18_05_struct_foreach_constraint.sv`](input/p18_05_struct_foreach_constraint.sv) compiled in both editions, but `randomize()` returned 0. VVP reported that the constraint item was unsupported by the solver rather than silently ignoring it. This isolates the foreach path from array-size selection.

The initial combined probe [`p18_04_struct_darray_sizes_foreach.sv`](input/p18_04_struct_darray_sizes_foreach.sv) is retained with its raw output; the reduced probes above separate its size and foreach results. Each compile and simulation had a 30-second subprocess timeout. Edition-specific stdout/stderr logs are in this directory.

## Toolchain and reproduction

- Host: macOS, Darwin 27.0, arm64.
- Source checkout: `38182f4ba2e7d17c99ab3ea31add1b8d99c51e36`.
- Build command: `PATH=/opt/homebrew/opt/bison/bin:$PATH ~/codex-supervisor/localrun 1200 make -j3`; exit 0. The matching build command, time and peak RSS are recorded in the preceding [§26.2 local build result](../../ieee1800-audit-c26-20261021/attempt-01-package-process/RESULT.md); this build produced the same Icarus executable SHA.
- Icarus Verilog 13.0-devel `9bd5082b8`; `iverilog` SHA-256 `b92ded447f28bda589f2eac77ea4ec09115687286bb69ada09e3e3a6b14882fc`; `vvp` SHA-256 `22dae2c8cc68f40455ded0f7d66a7a0700f784223b840c4fa3212700c28abc94`.
- Plain control runner: `~/codex-supervisor/localrun 120 python3 -` with paired `iverilog -g2017/-g2023` and `vvp` commands; exit 0, 0.39 s, peak RSS 36,536,320 bytes.
- Reduced struct size/foreach runner: same wrapper and edition commands; exit 0, 0.07 s, peak RSS 32,063,488 bytes. The probes expose unsupported forms as diagnostics or `randomize()` failure, and the harness records them as observations.

## Issue overlap and disposition

No new issue is proposed. Closed issue [#419](https://github.com/dsellerbrock/iverilog-uvm/issues/419) already tracks random variables below struct/container members. Its [DD-047 comment](https://github.com/dsellerbrock/iverilog-uvm/issues/419#issuecomment-6063470181) explicitly keeps nested dynamic-array size handling within #419 rather than opening a separate ticket. The lead should add these paired results to #419; A3 did not post or file an issue.
