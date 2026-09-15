# L78 — Constant-function string comparisons

IEEE 1800-2017/2023 6.16.6, 6.16.7 and 13.4.3.

One evaluator path handles compare and icompare, evaluates both operands once, compares unsigned bytes, folds ASCII case for icompare and returns a signed ordering result. Tests assert result signs, operand preservation, prefix/empty/high-byte boundaries, runtime parity and invalid calls.

Six permanent cases pass in each harness; 22 neighboring JSON cases pass. [Focused validation](2026-09-14_constant_string_comparison_validation.json) records the candidate artifacts. Broad batch qualification remains pending.
