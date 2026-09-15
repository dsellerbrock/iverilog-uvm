# L74 — Runtime string character compound assignments

IEEE 1800-2017/2023 6.16 defines a selected string character as a byte, with getc/putc conversion and bounds semantics. Clause 11.4.1 requires compound assignment to behave as read/operator/write with a single evaluation of each lvalue index. Both editions previously warned and skipped `text[index_once()] += 1`: ABC stayed ABC and the selector call count stayed zero.

The target now captures a signed two-state int index once, reads the byte using existing string extraction, applies existing vector compound arithmetic at the correct expression width, and writes through the existing putc operation. Invalid bounds, empty strings and zero-byte writes preserve string contents. The signed-character lvalue metadata fixed in L73 is a dependency for signed arithmetic and arithmetic-right-shift.

Six permanent cases pass in both harnesses. Coverage includes arithmetic/bitwise/shift operators, signed high bytes, wide RHS arithmetic, local/ref argument storage, negative/out-of-range/empty/zero-byte writes, mixed-X and wide-index conversion, selector and RHS single evaluation, and readonly rejection. Two byte-array/string neighbors and 34 shared evaluator/string neighbors also pass. Initial fixture errors involving signed bytes, implicit string conversions and zero-byte semantics are preserved in evidence/parallel-batch-l71-l72/l74-abi and root harness logs.

Scope is scalar string character storage, including local and referenced string variables. Whole-string compound operations, array receivers and string-function-return character stores retain separate implementation gaps; this fix does not qualify them. No new runtime opcode is needed.

The [validation record](2026-09-14_runtime_string_character_compound_validation.json) fingerprints the focused candidate. Broad batch qualification remains pending.
