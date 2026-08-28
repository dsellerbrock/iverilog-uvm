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

## 2026-08-27 clauses 6.16 and 11.4.12.2 — shared 2017/2023 rules

The implemented typed-string concatenation subset is shared between IEEE
1800-2017 and IEEE 1800-2023. Paired `-g2017`/`-g2023` regressions cover
contextual conversion of string literals, nested literal/string groups,
string expressions, explicit integral-to-string casts, fixed string-array
parameters, procedural assignments, and integral run-time replication. A
nested all-literal replicated group remains string-typed in a direct target,
a whole string cast, and both comparison operand orders. A string replication
or string-expression concatenation assigned to an integral target is rejected.
Zero and nonzero multipliers evaluate the replicated operand exactly once; a
zero multiplier produces the empty string.

For a concat operand whose parse-form declaration is a class type parameter,
the generic template body defers the hard operand-category decision until the
binding is concrete. Paired checks cover formal and property operands under a
`string` specialization and retain a hard error for the corresponding `int`
specialization. This is shared 2017/2023 specialization behavior, not an
edition delta.

Review hardening removes the implementation-specific runtime cutoff from new
typed bytecode. A legal **1,048,576-byte** variable repeat passes; lowering
preserves the multiplier's signedness; and negative, X/Z, or
runtime-index-width failure is diagnosed before returning the empty result. The
unsuffixed VVP opcode retains its historical behavior for existing textual
images and is covered by an independent fixture. These are shared 2017/2023
execution rules, not edition deltas. A host allocation exception also has a
controlled runtime diagnostic, but is not forced by a deterministic test.

String built-ins retain their exact `int`, `byte`, `integer`, `real`, or
`string` result type for data objects and constant string parameters. Their
zero-, one-, or two-argument arity is enforced before lowering, a method may
use a nested string concatenation as its receiver, and a scalar selected
string character is rejected as a string-method receiver because the select
has byte type. Constant parameter evaluation operates on semantic bytes, so
empty, nonprinting, backslash, and quote contents survive method folding.
Runtime indices and comparison operands remain legal when the receiver is a
constant string parameter, and constant string comparisons fold from semantic
bytes in either operand order.
Parentheses-free zero-argument static functions retain string
result type through the supported run-time concatenation. A static call in a
constant `localparam` concatenation remains a current gap, and the pre-existing
acceptance of a non-static `C::f` call is not included in the static-call
claim.

A real string expression mixed with an uncast integral expression is rejected
where the concatenation operator is formed. A conditional arm or a
whole-expression string cast therefore cannot hide the invalid operand. An
integral-only group still requires an explicit cast. The separately retained
`br_gh800` spelling is a narrow literal-only compatibility extension: it may
mix string and integral literals, but it does not admit an integral variable,
select, call, or other expression into a true string-expression
concatenation.

The positive reducer also distinguishes an all-literal group used in a string
context from the same literals used as a packed integral expression, and pins
null-byte removal during integral-to-string conversion. Final gates pass
**23/23 focused legacy**, **24/24 focused JSON/VVP**, **2,083/2,083 full
legacy**, **1,161 full JSON/VVP entries with 0 failures** (1,144 executed/pass
and 17 NI), **136/136 negatives**, **103/103 VPI**, **6/6 textual VVP
compatibility**, and **354/354 canonical real-DPI UVM** with no failures or
skips. Earlier same-branch OpenTitan Darjeeling/Earlgrey top replays, before
the final generic-class deferral hardening, move their former internal
typed-concatenation counts from **10/18** to **0/0**, but both tops still fail
later and no new full 61-target matrix was run. The final narrow deferral
change has not been replayed across those tops.

Two boundaries are intentionally not promoted to shared IEEE support. First,
direct `string[index]` is a byte expression; Slang 11 rejects that expression
as a string-concatenation operand. The narrowly admitted OpenTitan spelling is
therefore recorded as a compatibility extension, while an ordinary vector
select remains illegal without an explicit string cast. No VCS, Questa, or
Xcelium run was made. Second, Slang 11 rejects the standalone
`{0{"A"}}` string-context reducer because it permits a zero replication only
inside an enclosing concatenation. The implementation follows the direct
shared 2017/2023 string-replication interpretation and records this as a
narrow differential disagreement, not as a 2023-only rule.

Other bounded residuals are edition-independent and remain outside this
subset: a fixed-size unpacked signal-array string element has the correct
value but a wrong direct `.len()` result; `s.compare(65)` and the reverse mixed
comparison `{8'h41} == s` are pre-existing wrong acceptances; and a
parentheses-free static class call in a constant `localparam` concatenation is
still rejected. This section does not claim complete closure of either clause.

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

## 2026-08-27 clause 23.11 — no 2017/2023 delta

IEEE 1800-2023 retains the 2017 Syntax 23-9 bind target-instance shape: a
hierarchical identifier with constant bit selections. The implementation is
therefore shared across editions, and every new regression is registered as a
paired `-g2017`/`-g2023` case.

The paired evidence covers structured absolute, explicit `$root`, and
module/generate-relative target paths; selected one-dimensional loop-generate
and module-instance-array elements; declaration-scoped target-instance lists;
and per-owner conditional alternatives whose active occurrences have different
types or scalar/array shapes. A final instance array requires an element
select. Genvar and parameter expressions are evaluated per elaborated owner,
and deferred activation reaches a source-order-independent fixed point without
activating inactive or excluded owners. The same bound-instance name is legal
on disjoint targets and rejected on overlapping targets or existing
declarations. Target-kind regressions cover module/interface targets, legal
checker instantiation, and illegal checker/program/module/primitive contexts.
IEEE 23.11 restricts an interface target to an interface or checker bound
instantiation; the internal M13 fixture was corrected from module to interface
to conform to that rule, not to retain a compiler compatibility extension.
Library-only targets and paths are re-resolved after late `-y` loading, and a
library source may append a compilation-unit bind to the same closure. A
late-loaded UDP bound type retains the Syntax 23-9 error. Inactive/excluded
owners do not load or diagnose their library dependency. Automatic root
discovery accounts for a library-supplied compilation-unit bind found during
initial bind processing; it is not retroactively recomputed when a live
contained bind discovers one after roots were selected, so that exact-root case
uses explicit `-s`. The direct nested conditional-generate/generate-for path is
covered independently of bind. Dynamic, X/Z, range, path-shape, no-match,
duplicate, and bind-under-bind failures are loud and paired between editions.
The prior mainline rejects the selected positive paths in both editions.

The final native-ARM64 focused legacy and JSON/VVP harnesses each pass 110/110.
The full legacy manifest passes 2063/2063, the full JSON/VVP manifest passes
1141/1141, negatives pass 136/136, VPI passes 103/103, and the real-DPI UVM
umbrella passes 354/354 with zero failures/skips.
The parser conflict state is unchanged at 535 shift/reduce and 1119
reduce/reduce.

This is a shared-rule checkpoint, not complete clause-23 or 2023 support.
Multidimensional module-instance arrays remain outside the existing
one-dimensional compiler model; an exhaustive clause-23 combination audit is
still required for a complete claim. See the dated clause-23.11 section in
`matrices/ieee1800_2017_clause_matrix.md` and the associated session log.
