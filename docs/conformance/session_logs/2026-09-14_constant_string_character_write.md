# L73 — Constant-function string character writes

IEEE 1800-2017/2023 6.16, 6.16.2, 11.4.1 and 13.4.3 require byte character writes with putc(int,byte) conversion and constant-function locality restrictions. Both editions previously evaluated replacing the first character of ABC with Z as ABB.

The evaluator now replaces the selected character in the preserved string, converts the index to signed two-state int, and ignores out-of-range or zero-byte writes. Compound operations retain their RHS width/sign/state through arithmetic before final byte conversion. String-character lvalues now carry their resolved byte signedness, preserving arithmetic-right-shift and signed arithmetic in both constant evaluation and runtime lowering. Elaboration rejects nonlocal character writes in required constant functions with a counted error and marks ordinary functions performing those writes nonconstant. Locals and nested-block locals remain legal; ordinary runtime functions may still mutate module storage.

Twelve permanent cases pass in each harness, covering plain writes, conversion/bounds/empty/default strings, selector side effects, local and runtime controls, and module/imported-package/mixed-use nonlocal rejection. Two additional null-target generate oracles verify constant compound values across arithmetic, bitwise and shift operators: an incorrect result instantiates a missing module and fails elaboration. These checks assert semantic results; successful parsing alone is not their oracle. Thirty-four evaluator/string neighbors pass.

Review caught premature RHS narrowing, erased arithmetic-shift signedness, an uncounted evaluator diagnostic that allowed a later assertion, and incorrect initial test expectations. Earlier failures and the qualified-package-lvalue parser limitation are preserved under evidence/parallel-batch-l71-l72. Runtime compound character lowering is independently implemented by L74; it is not inferred from constant evaluation.

The [validation record](2026-09-14_constant_string_character_write_validation.json) identifies the mixed L73/L74 candidate used for focused integration checks. Broad batch qualification remains pending.
