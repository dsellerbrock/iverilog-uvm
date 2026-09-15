# L84 — Constant-function string-character increment/decrement

IEEE 1800-2017/2023 6.16, 6.16.2, 11.4.2 and 13.4.3.

The constant unary evaluator recognizes scalar string-character selections, captures the index once, resolves the local/input/return slot and reuses byte arithmetic and getc/putc semantics. Tests consume pre/post results to cover signed widening, wrap, invalid/zero stores, return-slot and recursive isolation, repeated calls, runtime parity and readonly/nonlocal rejection. A mixed string/byte concatenation in the first boundary fixture was invalid; explicit byte-to-string conversion repaired the fixture without compiler changes or removed cases. Two additional direct edition runs preserve scalar integer and real unary behavior.

6 cases pass in each harness; 40 neighboring JSON cases pass. [Focused validation](2026-09-14_constant_string_character_increment_validation.json) identifies the final candidate. Broad batch qualification remains pending.
