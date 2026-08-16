# Chapter 22 macro replacement context (2026-08-15)

Scope: the pinned sv-tests `22.5.1--define-expansion_21` polarity
mismatch and the adjacent macro replacement-token boundaries needed to
fix it without changing otherwise legal expansion.

## Reproduction and standard boundary

The source copied byte-for-byte into
`ivtest/ivltests/sv_macro_unterminated_string_fail.v` has SHA-256
`89ef0056eae0eb1f764615d9e6af96984c1084d1b40a305d6835d637f354da83`.
Before this change Icarus accepted it and emitted a display call whose
string started in the macro definition and ended at the invocation.
Pinned Slang 11.0.415 rejected the definition with a missing-closing-quote
diagnostic.

IEEE 1800-2017 clause 22.5.1 defines a macro replacement as replacement
tokens collected at the definition. It cannot form one string literal by
combining an opening quote in that replacement with a closing quote in a
later invocation context. Ordinary string literals are lexical tokens in
the replacement: a formal-argument spelling inside one is text, not a
formal reference. By contrast, the macro-quote operator deliberately
allows formal substitution while producing quoted text, and token paste
deliberately joins adjacent replacement tokens.

## Implementation

`ivlpp/lexor.lex` now tracks lexical context while collecting each macro
replacement across continued physical lines. Comment-looking text inside
ordinary strings and escaped identifiers is retained. Comments outside
those contexts are removed. Macro quote, escaped macro quote and token
paste are recognized before ordinary quote classification. An ordinary
string still open when the directive ends produces one error; the invalid
macro is not installed and its accumulated storage is released, allowing
the next directive to be parsed normally.

Formal-token discovery uses the same relevant boundaries. It skips
ordinary strings and escaped identifiers, preserves substitution inside
macro-quoted text, and still recognizes formals on either side of token
paste. Parentheses in a macro body or invocation remain replacement tokens;
no wrapper is inserted, so precedence continues to be controlled by the
macro author.

## Bounded expansion and recovery

Each preprocessor run now allows at most 256 simultaneously active macro
expansions and 1,000,000 aggregate expansions. The depth counter follows
macro input-stack ownership and is decremented when that expansion buffer
is released. A direct recursive reducer that previously exceeded the
resource runner's 1 GiB aggregate-RSS limit and was killed now exits in
0.02 seconds with one exact depth-limit error; `/usr/bin/time -l` recorded
1,843,200 bytes maximum resident set size. Mutual recursion hits the same
bounded path. A malformed definition followed by a valid one
reports the malformed definition once and expands the later definition,
demonstrating recovery rather than retained collector state.

The aggregate-count guard was code-audited but was not driven through one
million expansions; doing so would defeat the focused resource-bounded
test policy. Its counter cannot wrap before the comparison. Replacement
storage remains proportional to input and active expansion text, so very
large but nonrecursive generated input can still consume correspondingly
large time, output and memory. Finite nesting deeper than 256 is rejected
as an explicit implementation limit rather than risking process
exhaustion.

## Permanent evidence

- `sv_macro_definition_context`: runtime checks for parenthesized use,
  finite nested expansion, continued replacement text, comments inside a
  string, ordinary-string formal suppression, macro quote, escaped macro
  quote and token paste.
- `sv_macro_unterminated_string_fail`: exact copy of the pinned negative,
  with exact legacy and JSON stderr golds.
- `sv_macro_recursion_limit_fail`: exact direct-recursion depth diagnostic,
  with exact legacy and JSON stderr golds.
- `regress-macro-definition-focus-legacy.list`: 22/22 passed, including 19
  existing adjacent macro tests.
- `regress-macro-definition-focus-vvp.list`: 4/4 passed, including the
  existing string-escape test.
- Pinned sv-tests cases 18 through 26 matched Slang polarity exactly:
  18, 21 and 23 rejected; 19, 20, 22, 24, 25 and 26 accepted.
- The grammar was not changed: Bison remains 535 shift/reduce conflicts,
  1115 reduce/reduce conflicts and 201 conflicting states.

No full corpus, VM, CI gate or network operation was run for this focused
closure.
