# IEEE 1800 §10.7–§10.8 references

The probe follows IEEE 1800-2017 §10.7–§10.8, pp. 243–244, and IEEE 1800-2023 §10.7–§10.8, pp. 258–259.

## §10.7 assignment sizing

2017 §10.7: “When the right-hand side evaluates to fewer bits than the left-hand side, the right-hand side value is padded to the size of the left-hand side.” Signed right-hand values are sign-extended. “If the width of the right-hand expression is larger than the width of the left-hand side … the MSBs … shall be discarded.”

2023 §10.7 states the same padding and truncation requirements; it uses “may” rather than “can” for optional size-mismatch diagnostics.

## §10.8 assignment-like contexts

Both editions list typed parameter values, subroutine input arguments, function returns, and nondefault assignment-pattern correspondences as assignment-like contexts.

2017 §10.8 ends its list with: “No other contexts shall be considered assignment-like contexts.” Its list does not include static casts.

2023 §10.8 adds: “A static cast of an expression, as if to a variable of the target type.” Therefore the untyped pattern cast cases in `p10_08_cast_ctx.sv` are expected to compile in 2023 and be rejected in 2017. The typed-pattern control in `p10_08_cast_ctx_k0.sv` is expected to compile in both.
