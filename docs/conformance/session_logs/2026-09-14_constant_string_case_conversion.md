# L76 — Constant-function string case conversion

IEEE 1800-2017/2023 6.16.4, 6.16.5 and 13.4.3 govern toupper/tolower and constant functions. Both case-conversion directions previously failed constant evaluation; the string result path subsequently asserted. Runtime methods already worked.

One shared evaluator branch now evaluates the receiver once, copies its string value, converts ASCII letters in the selected direction and returns a fresh string constant. Empty strings, punctuation, digits and other byte values are preserved. No host locale is consulted and the receiver is unchanged. This is one case-conversion fix covering both directions.

Six permanent cases pass in each harness and forty neighboring string/evaluator cases pass. Tests cover local/argument receivers, constant and runtime receiver preservation, repeated calls, both directions, empty/high-byte values and focused arity/type rejection. Initial private JSON list/schema and legacy-vs-JSON path-prefix mistakes were corrected with the original files and failing logs preserved; they were not semantic passes.

The [focused validation record](2026-09-14_constant_string_case_conversion_validation.json) fingerprints the candidate with the integrated L75 target/runtime. Broad batch qualification remains pending. Other string methods are separate scope.
