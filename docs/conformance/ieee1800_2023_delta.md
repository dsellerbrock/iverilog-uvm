# IEEE 1800-2023 delta survey (M15 scoping record)

Recorded 2026-07-29 as Campaign 7's first M15 artifact. Method: two
independent, credible secondary sources read in full — K. Shinozuka,
"A Subjective Review on IEEE Std 1800-2023" (DVCon Japan 2024, written
against the published standard) and B. Pierce, "What's new in
SystemVerilog-2023? Part 1" (Dec 2023, SV committee member, exact
syntax-rule citations) — cross-checked with live probes against the
current compiler. Confidence labels are per item; nothing below is
bare recall. A final M15 scoping pass should still diff the actual
1800-2023 "Changes from previous edition" front matter (freely
available via IEEE GET) before implementation begins.

## Confirmed 2023 changes and fork status

| # | Item | Confidence | Fork status (probed) | Size |
|---|------|------------|----------------------|------|
| 1 | Triple-quoted strings `"""…"""` (5.9) | CERTAIN | UNSUPPORTED (lexer) | S |
| 2 | `ref static` tf arguments | CERTAIN | UNSUPPORTED (grammar) | M |
| 3 | Associative-array-typed parameters | CERTAIN | UNSUPPORTED | M |
| 4 | Restricted type parameters (`type enum/struct/class`) | CERTAIN | UNSUPPORTED | S–M |
| 5 | `type(this)` self-type | CERTAIN | UNSUPPORTED | M |
| 6 | Soft packed unions (`union soft`) | CERTAIN | UNSUPPORTED (hard packed unions work) | M |
| 7 | Named index iterator in array locator methods | CERTAIN | grammar accepts, binding missing ("Unable to bind `myidx`") | S |
| 8 | Array `map()` method (7.12.5) | CERTAIN | UNSUPPORTED but scaffolded — fails at elaboration on the shared `.method(iter) with` dispatcher, not at parse | S |
| 9 | Class `:final` specifier | CERTAIN | UNSUPPORTED | S |
| 10 | Constructor `default` argument keyword | CERTAIN | UNSUPPORTED | M |
| 11 | Method `:extends`/`:initial`/`:final` override specifiers | CERTAIN | UNSUPPORTED (no grammar) | M |
| 12 | Constraint `:extends`/`:initial`/`:final` | CERTAIN | UNSUPPORTED | S–M |
| 13 | `dist` catch-all `default :/ expr` | CERTAIN | UNSUPPORTED (isolated cleanly: base dist fine, `default:/` errors) | S |
| 14 | Covergroup `extends` in a subclass | CERTAIN | UNSUPPORTED by grammar inspection | M |
| 15 | `$timeunit`/`$timeprecision` system functions | CERTAIN | needs a dedicated probe (keyword-collision risk); tentatively UNSUPPORTED | S |
| 16 | `$stacktrace` standardized (task + string function) | CERTAIN | task form ALREADY IMPLEMENTED (R21, comment updated); string-function form open | doc + S |
| 17 | Preprocessor boolean `` `ifdef (A && B) `` (syntax 22-5) | CERTAIN | UNSUPPORTED (parenthesized-boolean form) | M |
| 18 | `weak_reference#(T)` | CERTAIN | UNSUPPORTED; needs GC/refcount hooks | L |
| 19 | `rand real` | CERTAIN | rejected at the single 18.4 choke point (clean relax site); real-valued solving itself is the work | L |
| 20 | Tolerance range operators `[a +/- b]`, `[a +%- b]` | CERTAIN | UNSUPPORTED by grammar inspection | S–M |
| 21 | Relational/equality results formally sized 1-bit | CERTAIN (clarification) | already conformant ($bits probes = 1) | N/A |

## Explicitly unverified (do NOT schedule without direct LRM citation)

Enhanced `disable` semantics; string↔real conversion changes beyond
`rand real`; Preponed-region clarifications; `$countdrivers`-family
additions; interface class changes; constraint implication changes
beyond items 12–13. Each was searched for and NOT found in either
source — treat as possibly-not-real until the 2023 LRM text is diffed
directly.

## Recommended adoption order (UVM relevance × cheapness)

1. `$stacktrace` doc alignment (done with this commit) + string-function form
2. Array `map()` (elaboration-only on the existing dispatcher)
3. `dist default :/`
4. Named locator index binding
5. Triple-quoted strings (pure lexer)
6. `ref static` (scheduler-adjacent; fits the M6B NBA expertise)
7. Class-declaration hardening cluster (items 9–12, shared territory)
8. Restricted type parameters + `type(this)` (items 4–5)
9. Assoc parameters, soft unions, `ifdef` booleans (3, 6, 17)
10. `rand real` (defer: solver-level)
11. `weak_reference#(T)` (defer: GC infrastructure)
