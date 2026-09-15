# L95 — Constant-function putc

IEEE 1800-2017/2023 6.16.2 defines putc as a string character update; 13.4.3 permits local built-in method mutations during constant evaluation. The internal task lowering previously returned success without evaluating either argument or changing the string.

The evaluator now evaluates the index and character once, applies the existing int/byte conversions and updates the scalar local or function-result string. Out-of-range writes and zero bytes leave the string unchanged. Elaboration rejects nonnumeric actual variables instead of accepting an implicit string-to-number conversion.

[Focused evidence](2026-09-15_constant_string_putc_validation.json) records paired runtime/folded comparisons, argument side effects, overwrite, negative/high/wide indices, zero-byte suppression, empty/default strings, byte truncation, real rounding, result-variable updates, purity and invalid-argument diagnostics. The private lists are `ivtest/regress-const-string-putc-{legacy,vvp}.list`.

This implements the scalar local receiver subset. Array receivers, other methods, broad compiler/UVM qualification and application qualification remain separate. The tested installed compiler also contained the in-progress L94 patch; source hashes identify this fix without qualifying that patch.
