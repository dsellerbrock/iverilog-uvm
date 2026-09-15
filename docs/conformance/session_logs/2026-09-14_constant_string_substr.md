# L80 — Constant-function substr

IEEE 1800-2017/2023 6.16.8, 13.4.3.

The constant evaluator reuses signed int string-index conversion and returns a fresh inclusive substring. Invalid ranges return the empty string. Tests cover local/argument receivers, preserved receiver values, repeated calls, runtime parity, empty/negative/reversed/end boundaries, high bytes, X/Z and wide index conversion, and arity/type rejection.

Six permanent cases pass in each harness; 28 neighboring JSON cases pass. [Focused validation](2026-09-14_constant_string_substr_validation.json) records exact artifacts. Broad batch qualification remains pending.
