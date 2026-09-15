# L75 — String-function-return character stores

IEEE 1800-2017/2023 6.16, 6.16.2, 11.4.1 and 13.4.1 define string character writes, compound assignment and the implicit function-name return variable. Both editions previously left that variable unchanged: plain byte writes evaluated the selector but discarded the write, while compound writes skipped the selector too.

A return-slot byte-store instruction now resolves storage using the existing function-frame conventions and applies putc bounds and zero-byte rules. Plain and compound return-character assignments use it; compound reads reuse the existing return-string load and selected arithmetic. The newly admitted path is restricted to scalar string returns, keeping array-return storage separate.

Eight permanent cases pass in each harness, plus fourteen runtime string/typed-return neighbors. Coverage includes plain/compound writes, signed and wide arithmetic, bitwise/shift operators, mixed-X/high-bit int conversion, negative/empty/zero-byte boundaries, selector/RHS single evaluation, nested RHS calls, automatic recursive return-frame isolation and readonly rejection. The first recursion test expected BAA instead of DAA; the independently recalculated oracle and explicit outer-frame isolation check replaced it, with the original failure preserved.

The [focused validation record](2026-09-14_string_return_character_validation.json) identifies source/artifact hashes and mixed-candidate provenance. Broad batch qualification remains pending. Whole-string compound operations and array-return character storage remain separate scope.
