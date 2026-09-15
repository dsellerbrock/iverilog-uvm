# L75–L84 compiler batch

Ten independently scoped fixes are integrated at semantic revision `240dd5f6f`. All seven broad gates passed on frozen candidate `304507aeb`. The [qualification record](2026-09-14_compiler_batch_l75_l84_qualification.json) owns counts, commands, artifact fingerprints and scope. This qualifies the recorded local compiler candidate, not full IEEE/UVM/application conformance. The UVM gate uses its existing 2012 invocation; the new focused cases are paired for 2017 and 2023.

| Fix | Implementation | Revision |
| --- | --- | --- |
| L75 | [Scalar string-return character stores](2026-09-14_string_return_character.md) | `f95f0bc11` |
| L76 | [Constant string case conversion](2026-09-14_constant_string_case_conversion.md) | `24feb1f28` |
| L77 | [Scalar string-character pre/post updates](2026-09-14_string_character_increment.md) | `d11c3852c` |
| L78 | [Constant string comparisons](2026-09-14_constant_string_comparison.md) | `cf34519c0` |
| L79 | [Fixed-array string-character stores](2026-09-14_array_string_character_store.md) | `d02896d77` |
| L80 | [Constant substr](2026-09-14_constant_string_substr.md) | `eb87a2593` |
| L81 | [Fixed-array string-character compound updates](2026-09-14_array_string_character_compound.md) | `45fcf1546` |
| L82 | [Constant string integer conversion family](2026-09-14_constant_string_integer.md) | `f517397bf` |
| L83 | [Fixed-array string-character pre/post updates](2026-09-14_array_string_character_increment.md) | `2d8d1cab6` |
| L84 | [Constant string-character pre/post updates](2026-09-14_constant_string_character_increment.md) | `240dd5f6f` |
