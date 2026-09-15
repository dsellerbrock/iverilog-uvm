# L77 — Runtime scalar string-character increment/decrement

IEEE 1800-2017/2023 6.16, 6.16.2, 11.4.2, 13.4.1.

The target now captures the signed int selector once, reads the byte from scalar or return string storage, and reuses the existing pre/post arithmetic and character store paths. Signed widened results, zero-byte store suppression, negative/empty indices, int conversion, recursive return isolation and const rejection are exercised.

8 permanent cases pass in each harness; 50 neighboring JSON cases pass. [Focused validation](2026-09-14_string_character_increment_validation.json) records the exact candidate artifacts. Broad batch qualification remains pending.
