# L81 — Fixed-array string-character compound assignments

IEEE 1800-2017/2023 6.16, 6.16.2 and 11.4.1.

The target captures both selectors once, loads the selected string byte, applies the existing signed byte compound operation and stores through the L79 opcode. Array function returns are explicitly excluded from the new path. Tests cover arithmetic, bitwise and shift operators, signed and wide operands, automatic/static declared bounds, side effects, invalid indices, character int conversion, zero-byte suppression and readonly rejection.

Eight cases pass in each harness and 28 neighboring JSON cases pass. [Focused validation](2026-09-14_array_string_character_compound_validation.json) records the final guarded candidate; broad qualification remains pending.
