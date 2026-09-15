# L83 — Fixed-array string-character increment/decrement

IEEE 1800-2017/2023 6.16, 6.16.2, 11.4.2.

The target reads string-array words through the string loader, captures both selectors once, reuses signed byte pre/post arithmetic and writes through L79. Tests cover all four forms, widened signed results, word isolation, automatic/static declared bounds, invalid/X/wide indices, empty/negative characters and zero-byte suppression. Readonly arrays and unsupported array-return destinations have focused rejection tests. Initial legacy negative registrations incorrectly used normal mode; corrected CE registrations pass. The original unused postfix-result witness took the compound-statement path; the final rejection witness consumes the result and exercises unary lowering.

8 cases pass in each harness; 36 neighboring JSON cases pass. [Focused validation](2026-09-14_array_string_character_increment_validation.json) identifies the final candidate. Broad batch qualification remains pending.
