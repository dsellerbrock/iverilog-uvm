# 2026-10-06 — IEEE 1800-2023 triple-quoted strings

## Rule

IEEE 1800-2017 §5.9 permits ordinary quoted strings, with a physical newline
only when preceded by a backslash. IEEE 1800-2023 §5.9 adds triple-quoted
strings, where raw double quotes and newlines are content; escaped newlines
continue to be removed. IEEE 1800-2023 §22.5.2 also keeps a macro definition
open across newlines inside a triple-quoted string.

## Change and focused result

The compiler lexer now keeps the triple delimiter, preserves raw newlines, and
emits a targeted edition error before 2023. The preprocessor protects literal
contents from macro/comment parsing and retains multiline macro bodies. The
registered `sv_triple_quoted_string_2023` test covers an embedded raw quote,
two raw newlines, `//` inside the literal, and an escaped newline inside a
macro. The paired `sv_triple_quoted_string_2017_fail` row checks the edition
gate.

The source-built ARM64 compiler compiled the test in strict `-g2023`; VVP
printed `PASSED`. Strict `-g2017` returned a compile error with the
IEEE 1800-2023 diagnostic. No full regression suite was run.

## Boundary

This closes only the exercised lexer and multiline macro paths. It does not
claim a complete audit of every string escape, macro argument form, or the
full IEEE string clauses.
