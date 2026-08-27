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

Unmodified UVM, OpenTitan, and Caliptra are application gates, not substitutes
for the standard. VCS, Questa, and Xcelium are the practical commercial-
simulator compatibility targets after the selected IEEE text; Slang is a
parser/elaboration differential and Verilator is diagnostic only. The work is
intended to leave a formal-ready frontend and SVA/IR foundation, but a proof
engine is later work and UPF/IEEE 1801 remains deferred.

## Candidate and previously probed 2023 changes; row-level direct-LRM closure pending

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
between `-g2017` and `-g2023`. Paired focused legacy and JSON/VVP gates now
pass 20/20 for each harness, including width/sign-preserving construction-time
ranges, X/Z rejection, coverpoint-domain conversion, descending ranges,
OpenTitan's TL-agent endpoint expression, open/fixed array-bin identity and
carving, per-instance dynamic-cross topology, automatic and named routing, and
cross-bin precedence/locality. This is a bounded clause-19 subset, not full
2023 functional coverage.

For both editions, integral `bins b[]` is value-keyed after range resolution:
duplicates and overlaps coalesce into one bin per distinct resolved value.
Fixed `bins b[N]` preserves ordered matching occurrences, places the remainder
in the final nonempty bin, and removes ignore/illegal values after distribution
without redistribution. Cross sampling uses the Cartesian product of every
matched source-bin identity. Named routing is independent of declaration
order, with `illegal` taking precedence over `ignore`, then normal bins; an
overlapping named normal bin counts at most once per sample, while different
named bins may each count.

The automatic-cross-bin edition delta is now directly audited. IEEE 1800-2017
19.6.1 p.572 requires retention of the nonintersecting automatic remainder and
its 19.7 Table 19-1 pp.578–579 has no retention option. IEEE 1800-2023 19.6.1
p.600 makes that behavior the default, and 19.7 Table 19-1 p.606 defines
`cross_retain_auto_bins` with default 1. When false, the presence of any
explicit cross bin removes every automatic bin. Syntax 19-4 pp.597–598 uses
`bins_keyword` for a cross-bin declaration, and Syntax 19-2 p.582 defines that
keyword as `bins`, `ignore_bins`, or `illegal_bins`; the presence rule therefore
includes all three. Applying it when a selector is empty is the direct
implementation consequence of “presence,” not a separate LRM example.

The option is instance-specific, not static. The construction-time option
assignment rule is on p.607; Table 19-2 p.608 permits it on a covergroup as the
default for crosses and on a cross as an override, but not on a coverpoint.
The implicit structures in 19.10 pp.613–614 put it in covergroup and cross
`option` and in no `type_option`. One p.607 sentence says “covergroup or
coverpoint definition”; that conflicts with both the table and the structures
and is recorded as an apparent editorial typo. The implementation follows the
table and structures.

The current compiler verifies constant covergroup defaults, constant
cross-local values, invalid coverpoint/`type_option` placement, and the 2017
edition rejection. Constructor/per-instance nonconstant expressions remain
open: the current `opt_uint` path diagnoses them and uses a default instead of
evaluating them per constructed object. The runtime presence mechanism covers
normal, ignore, and illegal records. The focused retention reducer pins an
ordinary explicit bin, a no-explicit-bin control, inherited covergroup defaults
on fixed and dynamic crosses, cross-local disable and enable overrides, and
empty ignore/illegal selectors. Procedural-write and repeated-assignment
evidence remains to be added.

Dynamic-family automatic crosses and the evidenced named
`binsof`/`intersect` conjunctions are verified with object-specific topology.
Current local gates are legacy **4,127 pass / 0 fail / 2 NI / 3 expected fail**
(**4,132 total**), JSON/VVP **1,017/1,017**, negatives **136/136**, VPI
**103/103**, canonical real-DPI UVM **354/354**, and both focused paths
**20/20**. The final OpenTitan matrix advanced seven targets from FAIL to
DEBT—from **1 DEBT / 57 FAIL / 3 SETUP_FAIL / 0 PASS** to **8 DEBT / 50 FAIL /
3 SETUP_FAIL / 0 PASS**—with zero timeouts/resource-limit signals and zero
exact or generic former cross-drop diagnostics. It is a compile matrix, not a
clean application or runtime pass. The final Caliptra static census completed
105 jobs and 420 compiler invocations: Icarus is **53/105** in each assertions,
no-assertions, and synthesis lane versus Slang **54/105**, with **52 PASS /
1 DEBT / 51 SHARED_SOURCE_OR_CONFIG / 1 SOURCE_ORDER_DEBT / 0 ICARUS_GAP**.
The sole Slang advantage is known `csrng_raw_wrap` source-order debt; this is
static compile/elaboration/synthesis differential evidence, not full DV
runtime. Constructor directions, transition-term illegal cross bins,
remaining dynamic `with`/`matches`/set/`CrossQueueType` selections, source
denominator carving, type-coverage union semantics, report/VPI and normative
naming detail, products over the explicit 65,536-bin cap, and the 2023
real/tolerance coverage surface remain open.

## Paired clauses 7 and 10 checkpoint (2026-08-26)

The shared 7.4/7.9.11/10.9.1 fixed-index and associative-array
assignment-pattern rules are now directly audited against both selected
editions and pinned with paired
`-g2017`/`-g2023` positive and negative evidence. The evidenced subset accepts
explicit constant string, integral, and enum keys plus at most one non-entry
`default`; it preserves declared-index conversion, duplicate diagnostics,
lexical once-only evaluation, fresh-value/atomic replacement, value copying,
and class-handle identity. Exact OpenTitan enum-to-string, enum-to-queue,
nested-map, and selected fixed-prefix forms are included.

This is a shared-rule checkpoint, not a 2023-only delta and not complete
clause closure. In particular, row 3 above—associative-array-typed
parameters—remains unsupported and is not implemented by assignment-pattern
support. The fixed-prefix evidence is limited to direct signal-backed
fixed-unpacked prefixes ending in integral/string/real-valued associative
leaves. Explicit/default real reads and direct stores are pinned. Every fixed
dimension is checked before flattening, so multidimensional OOB components
cannot alias valid sibling maps in stores, reads, or method calls; stores
retain once-only RHS evaluation. Packed bit/part/member and other
deeper/partial entry tails, property/member and struct-nested receivers, fixed
queue/dynamic-array leaves, fixed-prefix maps with class-handle/container/
struct values, and broader receiver/value contexts also remain loud or open.
The 2017 clause matrix keeps clauses 7 and 10 `PARTIAL` for those reasons.

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

## 2026-08-27 clause 12.7.1 — no 2017/2023 delta

IEEE 1800-2023 carries 12.7, 12.7.1, and Syntax 12-5 (including footnote 14,
which permits a `type_reference` data type only in the `var type(expr)` form)
unchanged from IEEE 1800-2017. The declaring for-loop implementation is
therefore edition-independent: no `-g2023` gate was added.

That is asserted rather than assumed. Every regression in the cluster is
registered as a 2017/2023 pair, and the four negative tests were confirmed to
produce byte-identical diagnostics under both editions before their gold files
were recorded. See the 2026-08-27 section of
`matrices/ieee1800_2017_clause_matrix.md` for the measured boundaries.
