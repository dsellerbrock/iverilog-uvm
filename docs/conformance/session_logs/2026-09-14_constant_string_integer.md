# L82 — Constant string-to-integer conversion family

IEEE 1800-2017/2023 6.16.9 and 13.4.3.

One shared parser now serves direct parameter folding and constant-function atoi/atohex/atooct/atobin. It scans radix-valid digits and underscores, stops at the first other byte, and produces a signed 32-bit result using defined modular arithmetic. The receiver is unchanged. No sign, size or base-prefix syntax is parsed.

Six cases pass in each harness and 34 neighboring JSON cases pass. Boundary tests compare all four radices across constant functions, direct parameter folding and runtime, including signed limits and truncation. Empty/invalid strings, high bytes, repeated calls and invalid call diagnostics are covered. [Focused validation](2026-09-14_constant_string_integer_validation.json) records the candidate; broad qualification remains pending.
