# OTBN scalar DPI `inout bit` copy-out

The pinned OTBN `otbn_core_model.sv` calls
`otbn_model_check(model_handle, check_mismatch_d)` inside an `always_ff`, then
queues `check_mismatch_q <= check_mismatch_d`. The DPI formal is `inout bit`;
the actual is a four-state `logic`. The selected compile warned that it skipped
copy-out of `mismatch`. Its generated VVP copied `check_mismatch_d` into the
formal with `%cast2`, called the function, and then read `check_mismatch_d` for
the NBA without a store from the formal back to the actual.

Two small reducers isolate this from OTBN and UVM:

- `ivtest/ivltests/sv_function_copyout_bit_formal_logic_actual.v` uses an
  ordinary SV function with `inout bit` and the same `always_ff`/NBA shape.
- `tests/m10_dpi_scalar_inout_logic_actual_test.sv` uses the same call shape
  through a DPI import. Its two-line C stub writes one through `svBit *`.

Before the fix, both strict 2017 and 2023 builds emitted the unsupported
function copy-out warning. Both simulations observed `check_ok=1` but
`mismatch_d=x` and `mismatch_q=x`. Thus the failure is shared function-call
lowering, not the DPI C ABI.

`tgt-vvp/draw_ufunc.c` receives the actual as an `IVL_EX_UNARY` expression
with opcode `2` (two-state conversion) around the original `IVL_EX_SIGNAL`.
The copy-out code accepts a signal lvalue but rejected this copy-in conversion
wrapper. It now unwraps only this conversion when the formal is two-state and
the source is a whole scalar two- or four-state signal and both the wrapper
and source retain the formal's width. The existing signal store then copies
out before the next NBA operand is read.
This code path serves ordinary SV and DPI function expressions through
`draw_copy_out_function_arguments`; its other caller is the selected
virtual-interface statement output path.

Focused verification on the fixed target:

| Check | Result |
| --- | --- |
| Strict 2017/2023 SV reducer, extensions disabled | `mismatch_d=1`, `mismatch_q=1`; no warnings |
| Strict 2017/2023 DPI reducer and C stub | `mismatch_d=1`, `mismatch_q=1`; no warnings |
| Legacy copy-out focus | 8 passed, 0 failed |
| JSON copy-out focus | 8 passed, 0 failed |
| Selected virtual-interface output caller | 1 legacy and 1 JSON test passed |

The DPI runner is part of `.github/ivtest_gate.sh`. No OTBN DV runtime or full
regression corpus was run during this focused fix. Pinned OpenTitan sources
were not changed.
