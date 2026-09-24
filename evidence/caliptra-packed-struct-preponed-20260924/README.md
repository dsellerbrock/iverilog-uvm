# Nested packed-select assertion sampling

The pinned Caliptra `KV_MLKEM_CHECK0` assertion compares two nested packed
selects across 8 words and 4 bytes. Icarus emitted 32 warnings that its left
operand was read live rather than in the Preponed region (IEEE 1800-2017/2023
§16.5.1). The paired [release-shaped reducer](packed_compare.sv) changes the
left operand with a blocking assignment in the assertion clock's time slot;
both operands had equal Preponed values. The installed compiler warned 32 times
and incorrectly reported 32 failures in each edition. A simple
[flat/select control](reducer.sv) already sampled correctly.

The one-file `elab_expr.cc` change samples the underlying whole signal before
rebuilding a chain of constant packed selects. Generated arithmetic indices
are proven constant with `eval_expr` on copies. The [paired ivtest](../../ivtest/ivltests/sv_assert_nested_packed_preponed.v)
adds a flat assertion that must fail once, so a disabled-assertion run cannot
pass. In both editions it changed from `nested=32 flat=1` with exit 1 to
`nested=0 flat=1` with exit 0, and the 32 warnings disappeared. Existing direct
select and packed-member assertion tests still pass. The
[dynamic-index boundary](dynamic_index_boundary.sv) retains one warning in
both editions: its index also needs a Preponed sample and is not covered by
this narrow fix.

Focused candidate runs used a private out-of-tree `ivl` executable via
`iverilog -B`, with the installed preprocessor, target, and VVP. The private
full `make all` stopped after linking `ivl` because the out-of-tree `ivlpp`
target could not find `lexor.o`; the focused compiler checks completed. Shared
installation, pinned top replay, and broad regressions remain coordinator work.
No pinned application source or shared build was changed.
