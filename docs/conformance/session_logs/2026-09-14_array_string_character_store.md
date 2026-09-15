# L79 — Fixed-array string-character stores

IEEE 1800-2017/2023 6.16, 6.16.2, 7.4, 10.4.1.

A minimal indexed string-array byte-store opcode uses native array accessors. The target captures normalized array and signed int character selectors once and preserves RHS byte conversion, invalid word/character suppression, empty strings and zero-byte no-op semantics. Tests cover static and automatic arrays, ascending/descending and nonzero bounds, selector/RHS side effects, wide/X indices, byte conversion and readonly rejection. Compound updates and other receiver kinds remain separate.

Six permanent cases pass in each harness; 32 neighboring JSON cases pass. [Focused validation](2026-09-14_array_string_character_store_validation.json) records exact artifacts. Broad batch qualification remains pending.
