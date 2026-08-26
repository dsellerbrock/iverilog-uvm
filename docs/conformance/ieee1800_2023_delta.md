# IEEE 1800-2023 first-class conformance survey

This began on 2026-07-29 as Campaign 7's M15 scoping record. The initial method
used two independent secondary sources — K. Shinozuka,
"A Subjective Review on IEEE Std 1800-2023" (DVCon Japan 2024, written
against the published standard) and B. Pierce, "What's new in
SystemVerilog-2023? Part 1" (Dec 2023, SV committee member, exact
syntax-rule citations) — cross-checked with live probes against the
current compiler. That historical provenance remains useful, but it is no
longer the normative basis.

IEEE 1800-2023 is now a first-class selected edition alongside 1800-2017.
Implementation and closure decisions must cite the locally consulted, ignored
`docs/standards/local/IEEE_Std_1800-2023.pdf`, compare the corresponding 2017
rule and applicable errata, and add executable `-g2023` evidence. The table
below is a scoping survey, not a complete clause matrix or a claim that every
probe is current. Secondary sources may help find deltas but cannot override
the selected LRM. Shared rules should normally have paired `-g2017`/`-g2023`
tests; changed rules need positive 2023 and edition-rejection evidence.

## Candidate and previously probed 2023 changes; direct-LRM closure pending

Keep `CERTAIN` below only as the historical scoping confidence. A row is not
closed until it has a direct-LRM citation, date, and executable edition gate.

| # | Item | Scoping confidence | Fork status (historically probed) | Size |
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

## Current paired clause-19 checkpoint (2026-08-26)

The typed constructor-dependent integral-bin work is intentionally shared
between `-g2017` and `-g2023`. Paired focused legacy and JSON/VVP gates pass
8/8 for each harness, including width/sign-preserving construction-time
ranges, X/Z rejection, coverpoint-domain conversion, descending ranges,
duplicate membership, fixed partitioning, and OpenTitan's TL-agent endpoint
expression. This is a bounded clause-19 subset, not full 2023 functional
coverage. Constructor directions, dynamic `with` and cross integration,
dynamic denominator/type/report semantics, and the 2023 real/tolerance
coverage surface remain open.

## Explicitly unverified (do not implement without direct LRM citation)

Enhanced `disable` semantics; string↔real conversion changes beyond
`rand real`; Preponed-region clarifications; `$countdrivers`-family
additions; interface class changes; constraint implication changes
beyond items 12–13. Each was searched for and NOT found in either
source — treat as possibly-not-real until the 2023 LRM text is audited
directly. This warning is about the items, not a reason to postpone the wider
2023 campaign.

## Historical 2026-07-29 scoping order (non-normative)

`ROADMAP.md` controls current priority. This list is retained to explain the
original survey ordering, not to postpone first-class 2023 work.

1. `$stacktrace` task-form documentation was aligned at the R21 checkpoint;
   the 2023 string-function form remains open
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
