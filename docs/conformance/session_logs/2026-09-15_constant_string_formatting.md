# L93 — Constant-function string formatting

IEEE 1800-2017 and 2023 6.16.11–6.16.15 define the five numeric formatting methods; 13.4.3 permits built-in methods on local variables in constant functions. The compiler lowered these methods to internal system tasks, then ignored them during constant evaluation, leaving receivers unchanged.

The evaluator now recognizes those five internal operations, evaluates the argument once and updates the scalar local string or function-result slot. Integer conversion and real formatting match the existing runtime implementation. Elaboration rejects nonnumeric actual string variables while preserving packed string literals and explicit integer casts. Genuine system tasks retain their existing constant-function treatment.

[Exact focused evidence](2026-09-15_constant_string_formatting_validation.json) records both editions, runtime comparisons, signed bounds and width conversion, real zero/negative/fraction values, repeated/nested updates, result-variable mutation, argument evaluation, purity and invalid-argument diagnostics. The focused lists are `ivtest/regress-const-string-format-{legacy,vvp}.list`.

Review corrected two invalid test assumptions: a ref formal is prohibited in a constant function by 13.4.3, and a packed string literal is a legal numeric actual. Separate edition golds retain exact diagnostic paths. Original failed runs remain in local evidence.

This is a focused implementation of scalar numeric formatting. Other mutating string methods, array receivers and broad qualification remain separate; it does not establish full constant-function, IEEE or UVM conformance.
