# Current evidence and work

## Current IEEE 1800 focus — 2026-10-07

**DD-104 locally qualified:** procedural `$past` history now captures static
signals from Preponed across inferred-edge, explicit-event, and default-clock
routes, including a writer-first same-edge blocking update. The simple
automatic-local `$past` case retains its current-value rule. Focused legacy
checks pass 5/5 rows and strict 2017/2023 JSON/VVP checks pass 10/10; these
totals include the expected compile-error checks for unsupported clocking-input
operands. Unsupported automatic forms fail closed. This is a bounded sampling
fix, not clause-16 closure. See the
[qualification evidence](../../evidence/procedural-past-preponed-20261007/README.md)
and [debt record](DISCOVERED_DEBT.md#dd-104--procedural-past-history-captures-the-active-region-value-not-the-preponed-value).

**Fix 37 locally qualified:** a randomized integral index can now select a
scalar integral or enum leaf through a fixed array of unpacked structs. The
paired test covers a 2-bit active-random selector and a state read with an
unselected X leaf; strict 2017/2023 JSON/VVP and legacy lists pass 2/2 each.
This remains bounded to fixed arrays of at most 65,536 words and scalar
leaves. Dynamic containers, aggregates, and wide coupled-domain sampling are
not qualified. See [qualification evidence](../../evidence/symbolic-indexed-outer-struct-constraint-20261007/README.md)
and [blocker record](BLOCKERS.md#randomize-indexed-outer-unpacked-struct-member).

**Fix 36 locally qualified:** constraints now resolve scalar integral and enum
leaves through fixed indexed arrays of unpacked structs, including nested
struct members and foreach-unrolled indices. The paired regression covers
descending and multidimensional ranges, randomized leaves, state reads, and
failed-solve rollback. Strict 2017 and 2023 legacy and JSON/VVP focus lists
pass 2/2 each. Symbolic fixed-array selectors are covered by Fix 37; dynamic
containers and aggregate leaves remain open. See the
[qualification evidence](../../evidence/indexed-outer-struct-constraint-20261007/README.md)
and [blocker record](BLOCKERS.md#randomize-indexed-outer-unpacked-struct-member).

**Fix 35 locally qualified:** strict `-g2023` now binds the optional array
method `index_argument` across locator, reduction, min/max, and `unique_index`
`with` expressions. This lets code use `item.index` for a real class member
while querying the array position through a chosen alias. Associative key
queries are covered too; strict `-g2017` rejects the second argument. The
paired new-case lists pass 2/2 in legacy and JSON/VVP, and adjacent 2023 map
lists pass 4/4 in each harness. This is a focused §7.12 gap, not full clause
closure. See [qualification evidence](../../evidence/array-index-argument-20261007/README.md)
and [blocker record](BLOCKERS.md#sv23-array-index-argument).

**Fix 34 qualified locally:** strict `-g2023` now accepts scalar class
`rand real` for the tested finite-interval constraint path, including real
comparisons, `inside` bounds, solve-before staging ahead of an integral bit,
and failed-call rollback. The 2023 positive, strict 2017 rejection, and
`randc real` rejection pass 3/3 in both legacy and JSON/VVP focus lists.
Unbounded or `dist` real solving, `shortreal`, real arrays/aggregate leaves,
and joint class-graph real solving remain unsupported. This is a bounded
increment, not closure of §18.4/§18.5.9. See the
[qualification evidence](../../evidence/rand-real-scalar-20261007/README.md)
and [blocker record](BLOCKERS.md#sv23-rand-real).

**Fix 33 qualified locally:** constraints on scalar integral/enum leaves now
work through finite nested unpacked-struct member paths rooted at a randomized
class property. The paired regression covers nested `rand`/`randc`, enum
membership, state-derived values, failed-solve rollback, and resumption. The
strict new-case lists pass 2/2 in legacy and JSON/VVP; adjacent struct/class
declaration lists pass 15/15 legacy and 14/14 JSON/VVP. Fixed indexed scalar
leaves are covered by Fix 36; symbolic selectors and aggregate, array, or
class-handle leaves remain open. See the
[qualification evidence](../../evidence/nested-unpacked-struct-constraint-20261007/README.md).

**Fix 32 qualified locally:** explicit `disable iff` now aborts supported
multi-boundary fixed-chain properties asynchronously across every clock
domain. The paired regression proves inter-clock cancellation, held-reset
gating, and resumed checking after release. Strict multiclock-control focus
lists pass 22/22 in JSON/VVP and 22/22 in legacy. The broader SVA clause stays
partial. See the [qualification evidence](../../evidence/sva-disable-multiclock-chain-20261007/README.md).

**Fix 31 qualified locally:** associative `find_last_index()` walks from the
last actual key backward and returns the first matching key in traversal
order, in a fresh queue with the declared key type. Strict paired JSON/VVP and
legacy lists each pass 8/8, including signed and string keys, empty/no-match
cases, existing associative locator neighbors, and wildcard-index rejection.
Other associative locator methods remain open. See the
[qualification evidence](../../evidence/assoc-find-last-index-20261007/README.md)
and [blocker record](BLOCKERS.md#assoc-find-last-index).

**Fix 30 qualified locally:** associative `find_first_index()` now visits the
actual ordered keys and returns the first matching key in a fresh queue with
the declared key type. Strict paired JSON/VVP and legacy lists each pass 6/6,
including signed and string keys, empty/no-match cases, existing `find_index`
neighbors, and rejection of wildcard-index arrays. Other associative locator
methods remain open; this does not close §7.12.1. See the
[qualification evidence](../../evidence/assoc-find-first-index-20261007/README.md)
and [blocker record](BLOCKERS.md#assoc-find-first-index).

**Fix 29 qualified locally:** strict 2023 accepts `default :/ expression` as
one aggregate-weight bucket over the complement of all explicit bins; strict
2017 rejects it. Its focused checks pass 5/5 in JSON/VVP and legacy harnesses,
and adjacent exact-dist checks pass 14/14 in each. Broader constrained-random
combinations, `randc`, and sparse/large domains remain useful open work. See
the [qualification evidence](../../evidence/dist-default-2023-20261007/README.md)
and [blocker record](BLOCKERS.md#sv23-dist-default-weight).

**Completed in fix 28:** nested object-property `solve-before` operands retain
their runtime solver identity. The paired staged-distribution and rollback
checks pass with fixed-array and randc controls; see the
[focused evidence](../../evidence/solve-before-array/cross-object-solve-before-20261007.md).

**Completed in fix 27:** `ARRAY-MAP-2023` passes the focused strict `-g2023`
runtime cases for fixed, dynamic, queue, and associative arrays; strict
`-g2017` rejects it. Unpacked-array-valued `with` results include empty inputs
and nested maps. See the [qualification evidence](../../evidence/array-map-2023-20261007/README.md).

**Uniform-solution checkpoint (2026-10-06):** the full registered paired
2017/2023 uniformity suites pass on fix-26 VVP
`e852bd40e42b279bd44e9fcb2665063b6106000112025cfd25e2e7da7a8a4787`
(229.09 s / 49.9 MB RSS and 198.16 s / 51.0 MB RSS). The adjacent failure-
rollback and fixed-array `solve-before` controls pass 6/6 in each harness and
edition. This qualifies the registered statistical cases; the residual
`randc` shapes listed below still keep clause 18 partial. Full evidence:
[uniform legal combinations](../../evidence/solve-before-array/uniform-legal-combinations-20261006.md#full-uniformity-checkpoint-on-the-fix-26-image-2026-10-06).

The direct-scalar subset, fixed unpacked bit arrays, and bounded variable-size,
one-dimensional integral and enum dynamic arrays now pass paired 2017/2023
statistical regressions. Fixed-array coverage includes two- and 129-element
one-dimensional arrays, a 2×2 array, and a 2×2×2 array with nine complete tuples at
12–55/300. The 129-element oracle's five bins are 91, 119, 90, 98, and
102/500; the 2×2 oracle's 17 bins each land between 30 and 90/1,000
(48–69 observed). Other coverage includes empty arrays, two correlated arrays, a
64/65-element size ratio, and 65-bit scalars with five-, 65-, and 129-tuple
domains. The 129-tuple oracle selects the 128-value branch 196/200 times; before
the wider-domain change it did so 101/200 times. Connected scalars wider than
64 bits enumerate small feasible unary domains and use full-width uniform
proposals with hard-solver rejection for larger connected domains. A dense
2⁶⁵-value case chooses its larger branch 200/200 times. Sparse domains above
the enumeration cap may take impractically many retries. The
isolated 65-bit scalar interval `[1:1024]` now samples four equal buckets
57, 54, 37, and 52 times per 200 draws in both editions. The fragmented
oracle uses `[1:768]` and `[1025:1280]`; four equal-cardinality bins stay
within 30–70/200 despite the 3:1 interval-size ratio. A 33-bit union with
nine equal 32-value runs has paired exact-sampling evidence; its old fallback
put 41/90 draws in the last run. Fix 11 removes the fixed run-count ceiling
and caps searches at 131,072 SAT checks per randomization. Fix 12 adds exact
full-domain rejection proposals for dense domains, keeping periodic 33-bit
legal-value bins at 100, 89, and 111/300 versus the biased fallback's 73, 74,
and 153. If interval search is indeterminate, bounded rejection is attempted
and randomization fails rather than using the biased diversity fallback.
Wider-than-4,096-bit values and cases that exceed both exact-work ceilings
remain open.
Variable-size arrays
with constrained element leaves retain the 512-element combined solver-model
cap. Arrays with no constrained element leaves use SAT binary searches to find
feasible size endpoints, then propose sizes in proportion to element-tuple
cardinality up to the existing 65,536 per-container allocation cap. Holes and
connected constraints are checked by the hard solver; sparse accepted sizes
can take many retries. The 512/513 bit-array oracle now chooses sizes 50/70
out of 120 and its first payload bit is one 55/120 times. The new 1,025-size
singleton-enum oracle produces four equal-size bins 108,99,96,97/400; the old
complete-model enumerator ran for 197.55 s before an interrupted run stopped
without a histogram. A 257-bit scalar interval now samples four bins 40,54,53,53
out of 200, versus 26,14,26,134 on the old fallback; the paired 80-draw oracle
passes under both editions. Fix 12's full registered suites pass in both
editions on source-built VVP SHA-256
`2c1dfe0ad2e2a82d6033192712131bc965cb82d8c7e3d6ff0790730c464a6970`:
2017 took 266.23 s (maximum RSS not captured), and 2023 took 231.86 s at
50,970,624-byte maximum RSS. Failure-rollback and fixed-array solve-before
controls also pass in both editions. After formatting and test-name cleanup,
the rebuilt image `e9c40812d1d49636fcc37c26135c62710d1465b8b2d64b1c89b1e54e9f479d39`
passes the focused periodic reducer and both registered suite sources compile;
the full suites were not repeated on that hash. The evidence page records the
paired full-run and latest focused results. The 128/129-size oracle now yields counts 91/209 out of 300; the
pre-fix path gave the size-128 mode 139/300. At 256/257, the new counts are
44/76 out of 120, versus 166/134 in the pre-fix 300-draw probe. Fixed
integral/enum arrays are sampled from referenced leaves without a declared-extent cap; the registered regression currently
covers one, two, and three unpacked dimensions. The array test retains the
ordered `solve m before q` control. The overall clause remains partial for
larger dynamic-array domains, fixed-array ranks above three and other shapes,
sparse randc domains that exceed the 65,536-proposal budget, graph-coupled,
static, and unconstrained wide randc values, wide domains above the exact
enumeration cap, nested, queue, associative, multidimensional, and struct/member
aggregate randc forms, ordering, additional soft-preference shapes, and weighted
`dist`. Non-static single-owner direct scalar randc properties 21–64 bits now
cycle only when the complete feasible set is exactly enumerated and contains no
more than 1,024 values. Non-static one-dimensional dynamic-array randc elements
21–64 bits wide are paired-tested when their complete feasible domain has at
most 1,024 values, including constant-index references from reachable parent
constraints. Other array shapes remain open.
The direct scalar constrained
randc fallback now samples uniformly from unseen values using hard-solver
checks and proves cycle exhaustion before reset. Paired strict 2017/2023 runs
complete two 128-value cycles with an unsatisfiable call between them. The
graph-coupled dynamic-array regression completes its 1,025-value cycle,
checks unsatisfiable rollback, and verifies reset under both editions. Struct,
fixed-array solve-before, and failure-rollback controls also pass on VVP image
`94916a850cacd433ec7e2fc52306947eab0f2360ce4de7cb91f09ff9ef8cd8b6`. The
full registered suites were not run on this image. See the
[blocker](BLOCKERS.md#constraint-uniform-legal-combinations--unordered-solutions-are-not-uniform).

Fix 14 extends the uniform tuple dependency graph to include satisfiable
explicit soft constraints. A soft-only scalar relation produces
`945,1012,1043/3000`; a fixed-size two-element dynamic-array relation produces
`1004,1009,987/3000` for their legal tuples under both editions. Their previous
fallbacks were biased at `948,916,1136/3000` and `718,751,1531/3000`. Existing
inherited-soft, alias-soft, and source-priority controls pass 3/3 per edition.
See the [focused evidence](../../evidence/solve-before-array/uniform-legal-combinations-20261006.md#satisfiable-soft-constraints-join-uniform-tuple-factors-fix-14).
The registered suite sources compile in both editions, but the full suites
have not been run on this image.

Fix 15 adds a fixed-array `foreach` soft-preference oracle. Its five preferred
complete tuples produce `594,590,592,612,612/3000` under both strict editions;
the pre-fix image produced `476,513,543,508,960`, overweighting one tuple.
The three tuples violating at least one soft clause remain absent. Both
registered suite sources compile with the added case; full suites remain
deferred to the 10-fix checkpoint. See the [focused evidence](../../evidence/solve-before-array/uniform-legal-combinations-20261006.md#soft-foreach-over-fixed-array-elements-fix-15).

Fix 16 adds a soft `foreach` check for a dynamic array whose hard size is tied
to another random variable. The LRM orders dynamic-array size constraints
before iterative constraints (2017 §18.5.8.1; 2023 §18.5.7.1), so the two
`(mode,size)` pairs are each selected half the time; payload values are then
uniform within each size. Paired results are `380,393,390,371,1466/3000`.
See the [focused evidence](../../evidence/solve-before-array/uniform-legal-combinations-20261006.md#soft-foreach-with-variable-dynamic-array-size-preserves-implicit-ordering-fix-16).

A separate 128-bit nested fixed-element diversity regression passes in both
editions. It uses a warned fallback for an oversized ordinary component and
does not extend the uniformity claim.

The 2023 §5.9 triple-quoted string lexer and multiline macro paths also pass a
focused 2023 runtime check; strict 2017 rejects the delimiter. See the
[session record](session_logs/2026-10-06_triple_quoted_strings.md).

## Current OpenTitan status — 2026-10-06

The latest candidate selected runtime result is the
[engine 367e aggregate](../../evidence/opentitan-census-20261002/candidate-runtime-engine-367e-aggregate-20261005/README.md):
**49/49 targets passed**. It combines 48 completed rows with a focused I2C
replay after making overlay staging idempotent. The earlier
[engine 890c candidate recheck](../../evidence/opentitan-census-20261002/candidate-runtime-recheck-20261005/README.md)
also passed 49/49 in matching 33- and 16-row serial segments. The earlier
[census18 result](../../evidence/opentitan-census-20261002/census18-xpack-runtime-20261005/README.md)
also passed 49/49, on the installed pre-candidate compiler.

Census18 used UVM 1.2 and `-gcommercial-unsafe`. This qualifies the selected
49-row runtime matrix, not every OpenTitan DV test.

The clean-source compile baseline covered 309 RTL/SVA/UVM rows on engine
`367e…`: 157 PASS, 120 dependency-only, 6 DEBT, 16 FAIL, 7 setup failures, and
3 upstream-invalid. The initial compile-only recheck against the reproducible
patched source snapshot produced 176 PASS, 120 dependency-only, 1 DEBT, 3 FAIL,
7 setup failures, and 2 upstream-invalid; all 35 UVM rows passed. These raw
results remain as historical baselines. See the
[patched-source census](../../evidence/opentitan-census-20261002/candidate-engine-367e-patched-source-compile-census-20261005/README.md)
and [clean-source baseline](../../evidence/opentitan-census-20261002/candidate-engine-367e-compile-census-20261005/README.md).

The latest 2026-10-06 scoped aggregate retains all 309 rows: four board targets
are `OUT_OF_SCOPE` under the Vivado-handled primitive policy, and 305 remain in
scope. Current in-scope counts are 188 PASS and 117 dependency-only, with no
FAIL, DEBT, setup-fail, or upstream-invalid rows. Of the dependency-only rows,
116 are helper cores compiled through passing parent top levels; `primgen` is
generator-only and exercised by passing parents. The Ibex compliance and
simple-system cosim targets now pass using support files from the exact Ibex
revision pinned by OpenTitan. See the [scope review](../../evidence/opentitan-census-20261002/candidate-engine-367e-patched-source-compile-census-20261005/board-primitive-scope-review-20261006/README.md),
[Ibex support library](../../evidence/opentitan-census-20261002/candidate-engine-367e-patched-source-compile-census-20261005/ibex-sim-shared-38c07093/README.md),
[compliance replay](../../evidence/opentitan-census-20261002/candidate-engine-367e-patched-source-compile-census-20261005/ibex-support-replay-r1-20261006/result.md),
[simple-system replay](../../evidence/opentitan-census-20261002/candidate-engine-367e-patched-source-compile-census-20261005/ibex-simple-system-cosim-replay-r2-20261006/result.md),
[provider replay](../../evidence/opentitan-census-20261002/candidate-engine-367e-patched-source-compile-census-20261005/orphan-provider-replay-r3-20261006/result.md),
[EnglishBreakfast replay](../../evidence/opentitan-census-20261002/candidate-engine-367e-patched-source-compile-census-20261005/englishbreakfast-rtl-replay-r3-20261006/result.md),
[Verilator follow-up](../../evidence/opentitan-census-20261002/candidate-engine-367e-patched-source-compile-census-20261005/englishbreakfast-rtl-replay-r5-20261006/result.md),
[EnglishBreakfast top replay](../../evidence/opentitan-census-20261002/candidate-engine-367e-patched-source-compile-census-20261005/englishbreakfast-rtl-replay-r6-20261006/result.md),
and [Earl Grey SVA replay](../../evidence/opentitan-census-20261002/candidate-engine-367e-patched-source-compile-census-20261005/chip-earlgrey-sva-replay-r8-20261006/result.md).
The [compile matrix](opentitan_matrix.md) has row details. The public Apache-2.0
Xilinx UNISIM models resolve the missing board primitive references in a
focused replay. Those board rows remain excluded under the current scope policy.
The compile census now has no in-scope failures under this policy; the separate
49/49 selected runtime gate does not cover every OpenTitan DV test.
The candidate passes the standalone OpenTitan AST reproducer 20/20 and three
related sparse-case regressions 3/3. See the [AST synthesis evidence](../../evidence/opentitan-ast-synthesis-abort-20261004/README.md).

The default `rom_ctrl`, `top_earlgrey`, and `chip_earlgrey_asic` synthesis
rows pass with a build-local overlay that guards only simulation path-printing
and retains `$readmemh`. These RTL results are included in the refreshed
engine `367e…` census. The `chip_earlgrey_asic` SVA row now passes after the
runner applies its imported `1ns/1ps` default; Icarus's mixed-timescale notice
remains recorded as benign. The selected 49-target runtime gate also passes on
this engine; the scoped RTL/SVA/UVM census has no in-scope compile failures.
See the [ROM loader evidence](../../evidence/opentitan-romctrl-memload-synth-overlay-20261005/README.md)
and [Earl Grey result](../../evidence/opentitan-census-20261002/candidate-memload-synthesis-default-image-20261005/README.md).

The I2C SVA and UVM compile rows also pass on engine `367e…` with the qualified
warning-cleanup overlay; both are included in the refreshed census. See the
[I2C follow-up](../../evidence/opentitan-census-20261002/candidate-i2c-qualified-warning-cleanup-20261005/README.md).

Four SVA rows previously marked `DEBT` now pass after the setup-warning
classifier verifies that warned C/C++/Python files are absent from the Icarus
source lists. Their clean statuses are included in the refreshed census. See
the [SVA follow-up](../../evidence/opentitan-census-20261002/candidate-sva-setup-classification-20261005/README.md).

The SPI Host SVA target also passes after a build-local correction removes its
reference to an undefined FuseSoC fileset. See the [SPI Host result](../../evidence/opentitan-census-20261002/candidate-spi-host-sva-fileset-20261005/README.md).

The Keccak 2-share FPV target now passes on engine `367e…` with a build-local
control model matching the current DOM-based DUT. See the
[focused result](../../evidence/opentitan-census-20261002/candidate-keccak-2share-fpv-dom-controller-20261005/README.md).

The Keccak round FPV target also passes; its clear signal now uses the DUT's
`mubi4_t` encoding. See the
[focused result](../../evidence/opentitan-census-20261002/candidate-keccak-round-fpv-mubi4-clear-20261005/README.md).

The `prim_lfsr` FPV target now passes with disjoint build-local vector indices
for its linear and nonlinear instances. This resolves duplicate `state_o`
drivers without changing pinned source. See the
[focused result](../../evidence/opentitan-census-20261002/candidate-prim-lfsr-fpv-disjoint-slots-20261005/README.md).

The `prim_packer` FPV target now passes with separate output slots for each of
its 17 DUT instances, resolving the shared-output multiple drivers. See the
[focused result](../../evidence/opentitan-census-20261002/candidate-prim-packer-fpv-disjoint-outputs-20261005/README.md).

The SHA3 FPV wrapper now matches the current DUT ports, MuBi controls, and
random input width; its focused compile passes without debt. See the
[focused result](../../evidence/opentitan-census-20261002/candidate-sha3-fpv-current-interface-20261005/README.md).

The AES wrapper RTL row now passes after removing its duplicate data-integrity
driver and matching the AES idle output's MuBi width. See the
[focused result](../../evidence/opentitan-census-20261002/candidate-aes-wrap-single-data-integrity-driver-20261005/README.md).
The 309-row census totals remain unchanged.

The `lowrisc:fpv:sha3pad_fpv:0.1` SVA row now passes a focused compile with a
hash-checked overlay for its current DUT ports, MuBi controls, and sampled
digest. The pinned source is unchanged; the frozen 309-row census still records
this row as upstream-invalid. See the
[focused result and patch](../../evidence/opentitan-census-20261002/candidate-sha3pad-fpv-sampled-mubi-20261005/README.md).

The measured hot paths and coverage limits are summarized in the
[native hot-path analysis](../../evidence/opentitan-census-20261002/census12-full-corpus-20261003/HOTPATHS.md).

## Uniformity checkpoint — 2026-10-06

The selected blocker is unordered uniformity over legal constraint
combinations. The current branch rejection-samples coupled scalar, referenced
fixed-array, and bounded direct integral/enum-array tuples. Paired `-g2017` and
`-g2023` checks cover Table 18-2, two- and 129-element fixed arrays, 2×2 and
2×2×2 fixed arrays, empty arrays, correlated arrays, 64/65-element arrays, and
65-bit scalars. The new isolated
65-bit `[1:1024]` interval oracle passes with bins 57, 54, 37, and 52/200.
The fix-10 nine-run regression remains historical paired evidence. Fix 11
removes its fixed 16-run ceiling and caps boundary searches at 131,072 SAT
checks per randomization. Fix 12 adds exact uniform rejection proposals for
dense domains and explicit failure when bounded exact sampling cannot decide.
The registered dense periodic 33-bit regression samples bins 100, 89, and
111/300; its old fallback gave 73, 74, and 153. Full registered suites passed
under strict `-g2017` and `-g2023` on fix-12 image
`2c1dfe0ad2e2a82d6033192712131bc965cb82d8c7e3d6ff0790730c464a6970`. The
post-cleanup rebuild passes the focused periodic reducer and both registered
suite sources compile; the full suites were not repeated on it. Cases that
exhaust both exact-work budgets, unconnected widths above 4,096 bits, and
fixed-array ranks above three remain open.
The 65-bit scalar boundary oracle covers 65 legal tuples and is uniform within
the recorded threshold when the finite wide-domain cap is 256 values. Variable-size
dynamic arrays now use the exact sampler through 512 combined elements. The
128/129 size multiplicities sample 91/209 times in 300 draws; 256/257 samples
44/76 times in 120 draws. A variable-size enum array with three declared
values and sizes one or two now samples the 3:9 tuple ratio at 29/91 out of
120, after the prior fallback produced 67/53.
Fixes 18–19 extend exact constrained `randc` handling to a graph-coupled
scalar and a non-nested fixed-array leaf. The paired 1,025-value fixed-array
cycle completes without repeats and starts a new cycle.
Fix 20 removes the blanket refusal of soft constraints on cyclic object graphs;
a paired two-object cycle checks soft preference, failure rollback, and retry.
Fix 21 adds direct one-dimensional dynamic-array randc elements to the graph
sampler and commits the first selected value after initial array growth. Other
cyclic soft combinations and nested, queue, associative, multidimensional, and
struct/member randc forms remain open.
Fix 22 adds a bounded sparse-history path for non-static direct scalar randc
properties through 64 bits when the exact feasible set contains at most 1,024
values. Paired strict 2017/2023 cycles include an unsatisfiable retry before
exhaustion and verify reset. Histories cap at 65,536 values per property;
graph-coupled and other wide randc forms remain open.
The [focused evidence](../../evidence/solve-before-array/uniform-legal-combinations-20261006.md#bounded-sparse-history-for-constrained-wide-randc-fix-22)
records the paired result and source-built image hashes.
Fixes 25–26 extend that bounded sparse history to one-dimensional dynamic-array
elements through 64 bits, first for owner-local constraints and then for
constant-index references from reachable parent constraints. Each tested
21-bit element cycles through 65 values, preserves history on failed
randomization, and resets after exhaustion; 1,025-value domains fail closed.
Strict 2017/2023 focused JSON and legacy pairs pass. The full registered suites
remain deferred to the 10-fix checkpoint. See the
[focused evidence](../../evidence/solve-before-array/uniform-legal-combinations-20261006.md#parent-referenced-wide-dynamic-array-randc-elements-fix-26).
The 128-bit nested fixed-element check also passes through its warned,
non-uniform fallback. Larger domains and other unsupported solver shapes
remain open; this is not full IEEE constraint-solver qualification. See
the [focused result](../../evidence/solve-before-array/uniform-legal-combinations-20261006.md)
and the [blocker limits](BLOCKERS.md#constraint-uniform-legal-combinations--unordered-solutions-are-not-uniform).

## Earlier OpenTitan and Caliptra evidence snapshots

The earlier selected 52-case Caliptra L0 run used Icarus with explicit
`-gcommercial-unsafe` as the main **nonstandard compatibility** lane. A pass
still requires the intended marker, zero fail/error/assertion diagnostics,
and meaningful firmware execution. Strict mode supplies focused IEEE
mixed-driver rejection controls; its full-top compile failure is baseline
evidence. Named Caliptra and OpenTitan patches and options are selected per
test on disposable copies under the [release overlay guide](release_overlays/README.md),
leaving pinned source checkouts unchanged.

The [2026-09-25 OpenTitan unsafe DV baseline](../../evidence/opentitan-cover-open-range-20260925/latest-unsafe-matrix.md)
uses the combined private Icarus compiler (`ivl` SHA-256
`9084fca0b6d1cbe00184583399ba1c5fcf0f10d78402f42c14fd50c3708dbdfe`)
and explicit `-gcommercial-unsafe` for all 84 selected compile rows. This
matrix uses the pinned base-source filelists; test-specific OpenTitan overlays
are recorded as separate named replays. Of 35
UVM rows, nine compile with debt and 26 fail; of 49 runtime rows, seven are
classified `DEBT`, 35 fail compilation, six fail at runtime, and one times out.
There are **0/49 zero-debt raw matrix `PASS` statuses**. All seven `DEBT`
runtime rows complete their selected checks with meaningful traffic and zero
runtime errors; adding the two current-image OTP/CSRNG named patched replays
and two PRESENT/PRINCE native-DPI replays gives **11/49 selected smoke
identities passing nonstandard compatibility DV**. The remaining **38**
comprise 33 compile failures, four runtime failures, and one timeout; these
are not 38 distinct compiler bugs. HMAC advances from a
hard compile error to checked runtime traffic but reports a CSR status
`UVM_ERROR`; VVP exit zero does not qualify it. The pinned OpenTitan
checkout remains unmodified. This is nonstandard compatibility evidence;
paired strict IEEE reducers and UVM regression counts are separate.

The [previous PR #374 unsafe DV baseline](../../evidence/opentitan-icarus-dv-baseline-pr374-unsafe-20260925/README.md)
uses the private PR #374 Icarus compiler at `1d2aca710` and
`-gcommercial-unsafe` for **all 84** selected UVM/runtime compile rows.
The [per-row table](../../evidence/opentitan-icarus-dv-baseline-pr374-unsafe-20260925/results.md)
records 8/35 UVM compiles with debt and 27 failures; among 49 runtime rows,
eight complete with pass banners and debt, 36 fail compilation, and five fail
runtime. There are **0/49 clean, qualified matrix DV passes**, unchanged from
the [previous full unsafe baseline](../../evidence/opentitan-icarus-dv-baseline-unsafe-20260925/README.md).
The pinned OpenTitan checkout is unmodified. EDN's former package-type parse
errors clear, but three dropped coverage bins still block its runtime; OTBN's
same parse blocker clears, but later hard diagnostics remain. Earlier
disposable-overlay OTP and CSRNG named smokes each passed **1/1 named
nonstandard compatibility DV** on their recorded private tool images; they
were not rerun or included in the PR #374 base-source matrix or IEEE counts.

The [merged PR #373 `$system` return-value fix](../../evidence/opentitan-system-return-20260925/README.md)
passed paired 2017/2023 direct reducers on its recorded private VVP.
The pinned released `prim_prince_sim` compiles with `-gcommercial-unsafe` and,
after loading its native DPI model, completes **1/1 named checked nonstandard
compatibility replay**: five golden and one random vector, reference-model
encryption/decryption checks, one `TEST PASSED CHECKS`, and zero runtime
errors or assertions. On that recorded image its base matrix row was `DEBT`
because of three runner-tracked FuseSoC setup warnings and a separate raw
backend-deprecation warning. That image's raw matrix instead records
`RUNTIME_FAIL` without the native DPI symbol, while the current-image
[native-DPI replay](../../evidence/opentitan-cover-open-range-20260925/native-dpi-replays/README.md)
completes its original checks. Neither raw matrix row qualifies as a
zero-debt pass. Extra-argument `$system` acceptance is tracked
separately as DD-062; no full chapter-20 conformance claim follows.

The [open-ended covergroup range follow-on](../../evidence/opentitan-cover-open-range-20260925/README.md)
preserves HMAC's upper-length bin and cross. Its pinned smoke runs real message
traffic with `-gcommercial-unsafe`, but a CSR status mirror mismatch reports
`UVM_ERROR` and `TEST FAILED CHECKS`: **0/1 released HMAC DV**. The full 84-row
rerun above is on this image. Paired strict 2017/2023 reducers qualify constant
open range bins and transitions, not the nonstandard application replay. The
combined-image local gates pass full legacy 6,694 total with zero unexpected
failures, JSON/VVP 3,743/3,743, VPI with PLI1 140/140, and REAL DPI UVM
358/358; these counts are separate from released DV.

On that same compiler, the documented disposable-source [OTP RAM-path
overlay](../../evidence/opentitan-cover-open-range-20260925/otp-current-overlay/result.json)
and [CSRNG width overlay](../../evidence/opentitan-cover-open-range-20260925/csrng-current-overlay/result.json)
each complete a named `-gcommercial-unsafe` smoke with native DPI and the
original checks: **2/2 named nonstandard compatibility DV**, separate from the
base-source matrix's 0/49. OTP records 1343 checked TL A/D pairs with six bin
groups and 36 endpoints retained; its warned fault-injection branches are
unexercised by this seed. CSRNG records ordered app-2 instantiate, generate,
and uninstantiate traffic; one constraint item remains ignored at compile.

The same current-image [PRESENT and PRINCE native-DPI replays](../../evidence/opentitan-cover-open-range-20260925/native-dpi-replays/README.md)
reuse their exact unsafe matrix-compiled programs, load the required pinned
reference models, and complete golden and random encryption/decryption checks:
**2/2 named nonstandard compatibility DV**. PRESENT retains six compile-time
multiple-driver compatibility warnings. The raw matrix remains 0/49
zero-debt passes; prior pwrmgr and xbar source patches add no distinct selected
identity because their base-source rows already pass checked smokes.

On an earlier private OpenTitan Icarus image recorded in the [OTP cover-bin
endpoint replay](../../evidence/opentitan-otp-cover-bin-method-20260925/README.md),
the pinned `otp_ctrl_smoke_vseq` completes **1/1 released nonstandard
compatibility DV** with six previously dropped coverage bins retained,
1343 checked TL A/D pairs, and zero UVM or assertion failures. The same
image separately recompiles and passes pinned `csrng_smoke_vseq` **1/1
nonstandard compatibility DV** with checked app-2 instantiate/generate/
uninstantiate traffic. These are two named tests, not a full OpenTitan
suite rate. OTP's after-alert bin hits and fault-injection `force` branches
are not qualified by this seed; CSRNG's ignored `int_state_read_enable_c`
item remains separate. Strict OTP compilation rejects 36 unproven nested
receiver endpoints and has no released runtime. The paired strict reducer,
UVM regression, and released-DV denominators are distinct.

On the `e75f26091` main baseline with local candidate changes, the
[fresh Icarus application DV census](../../evidence/icarus-dv-baseline-20260923/README.md)
records **0/52 strict Caliptra L0 runtimes attempted**: the [integrated PIC
strict top compile](../../evidence/caliptra-icarus-l0-strict-pic-nullguard-20260924/summary.json)
exits 46 on 46 mixed interface-member variable-driver errors, with zero
Preponed sampling warnings and the release's internal-TRNG define. The opt-in `-gcommercial-unsafe`
candidate compiled the pre-PIC top only after proving each overlapping task writer
unused for its concrete interface instance; called and uncertain writers
still fail. The [pre-PIC exact native-vector first compatibility
runtime](../../evidence/caliptra-icarus-l0-unsafe-final-first-20260924/smoke_test_veer/result.json)
was **0/1 attempted**, with 51 unrun, simulation exit 1, zero pass/fail
markers, 17,467 bad diagnostics and 621 instruction-trace entries. Its
reported retired-instruction and cycle counters are zero because no final
CSR dump was reached. Original TLU, SOC IFC and LSU assertions act at
43.865 us, and compile emitted zero Preponed sampling warnings. This remains
historical nonstandard compatibility evidence. The [integrated PIC focus](../../evidence/caliptra-pic-integrated-focus-20260924.log)
passes 4/4 paired cases. Its [initial exact unsafe first-case compile](../../evidence/caliptra-icarus-l0-unsafe-pic-first-20260924/summary.json)
crashed exit 139 on a null `Nexus::first_nlink()` in the new cprop reachability
traversal; an integrated null guard now lets the exact top compile to VVP. The
[completed exact first-case replay](../../evidence/caliptra-icarus-l0-unsafe-pic-nullguard-first-20260924/smoke_test_veer/result.json)
is nonstandard compatibility **0/1** with 51 unrun. Firmware and simulation
exit 0 with one pass marker, zero fail markers, 633 retired instructions,
4,348 cycles, and 634 trace commits, but 17,863 bad diagnostics fail the
unchanged zero-error gate. The former terminal 43.865 us SOC/TLU/LSU fatal
is absent, a runtime advance without an L0 pass. PIC source work is
suspended for error-root review after the P1 broad legacy, JSON, and REAL DPI UVM gates passed.

On the later installed P1 compiler (`ivl` SHA-256
`6ec92c4825dc51e3810d1cb22405071f033015626d39cf3db92c319aeb9d3b10`),
the [shared paired virtual-dispatch focus](../../evidence/caliptra-unsafe-virtual-dispatch-20260924/shared_focus.json)
passes 28/28. Its [strict full-top guard](../../evidence/caliptra-icarus-l0-strict-p1-20260924/README.md)
still exits 46 on exactly 46 genuine mixed-driver errors, with zero other
errors or Preponed warnings and no L0 runtime. The [P1-install broad legacy gate](../../evidence/caliptra-virtual-final-ivtest-gate-20260924.log) passes with 6,555 total, 6,550 ordinary passes, zero failures, two not implemented, and three expected failures; bundled VPI 131/131, negatives 155/155, and invariants 15/15 also pass. The [final REAL DPI UVM gate](../../evidence/caliptra-virtual-final-real-dpi-uvm-20260924.log) loads REAL DPI and passes 358/358 with both VIF smokes. The [P1-install full JSON compiler/VVP gate](../../evidence/caliptra-virtual-final-json-gate-20260924.log) passes 3,536/3,536 with zero failures; pristine compatibility review remains; [PR #350](https://github.com/dsellerbrock/iverilog-uvm/pull/350) is open.
The completed [bundled-BFM reset-copy diagnostic](../../evidence/caliptra-icarus-l0-diagnostic-reset-vif-20260924/README.md)
is separately **0/1** with 51 unrun: firmware and simulation exit zero,
one pass marker, 633 retired instructions, no startup errors, and exactly
17,844 vacuous KV/MLDSA checker messages as its only bad diagnostics. A
[six-nanosecond passive trace](../../evidence/caliptra-l0-timezero-passive-vpi-20260924/README.md)
records unknown reset-dependent checker inputs before the first clock
without assigning simulator or testbench causality. Pins and tool
fingerprints remain clean. The zero-error gate rejects the reset-copy case;
its diagnostic denominator stays separate from pristine unsafe
compatibility. The frozen [four-helper checker patch and paired controls](../../evidence/caliptra-l0-checker-source-overlay-20260924/README.md)
pass 4/4 paired 2017/2023 combinations, and the opt-in top compile exits
zero with zero sampling warnings. The [combined reset/checker disposable-copy first case](../../evidence/caliptra-icarus-l0-diagnostic-combined-p1-20260924/README.md) passes diagnostic qualification **1/1** with 51 unrun, zero bad diagnostics, one pass marker, 633 retired instructions, 4,348 cycles, and 634 trace commits. Pristine unsafe remains **0/1**; this diagnostic result is neither an IEEE nor a pristine L0 pass. The preliminary sequential `--all` diagnostic run was intentionally stopped during `smoke_test_mbox` after `smoke_test_veer` printed PASS. Its preserved partial output at `evidence/caliptra-icarus-l0-diagnostic-combined-all-p1-20260924/` is unqualified and has no aggregate verdict. The [during/after provenance record](../../evidence/caliptra-l0-active-sweep-provenance-20260924/README.md) confirms both copied firmware trees match 5,139 pinned non-Git entries except each case's named patch, and the xPack GCC 15.2 toolchain hashes stayed unchanged. Pinned sources remain clean.

A focused [ephemeral JTAG port check](../../evidence/caliptra-icarus-l0-runner-20260923/check_ephemeral_jtag_port.py) passes for a hash-guarded disposable copy of only the pinned top testbench: its sole `ListenPort` changes from `63224` to `0`, and JTAG server/bind errors fail the runner even with a pass marker. The opt-in `--commercial-unsafe --reset-overlay --checker-source-overlay --ephemeral-jtag-port` profile has qualification `diagnostic_reset_checker_source_ephemeral_jtag_port_overlay`. The [same-profile first case](../../evidence/caliptra-icarus-l0-ephemeral-jtag-first-20260924/README.md) passes separate diagnostic qualification **1/1** with 51 unrun, firmware/VVP exits zero, one pass marker, zero bad/DPI/JTAG diagnostics, 633 retired instructions, 4,348 cycles, and 634 trace commits; source/tool integrity matches. The [bounded four-job exact 52-case wrapper](../../evidence/caliptra-icarus-l0-parallel-runner-20260924/README.md) was deliberately SIGTERM-stopped after one completed `smoke_test_veer` PASS; its partial output at `evidence/caliptra-icarus-l0-patched-52-20260924/` is unqualified, with no aggregate result or orphan VVP. Longer first-cohort cases were still in released CRT `.data` copy loops: static map/disassembly shows about 17,700-17,900 instructions to `main` versus about 2,400 after 22 minutes, making the 1,800-second limit insufficient. A same-profile `smoke_test_mbox` pilot with `--timeout 14400` is active at `evidence/caliptra-icarus-l0-mbox-long-pilot-20260924/`. There is no 52-case aggregate result, pristine unsafe pass, or IEEE pass from this checkpoint.

An Icarus interface-port initialization fix cleared the initial null virtual interface, and native
vector generators now stage successfully. A hash-guarded reset-timing copy
probes a startup race; passive evidence does not yet assign simulator-versus-testbench cause. A
[paired AES reducer and fix](../../evidence/caliptra-aes-sensitivity-fix-20260923/README.md)
clear its subsequent time-zero sensitivity stall in both editions. The fresh
[copied-reset first case](../../evidence/caliptra-icarus-l0-diagnostic-aesfix-first-20260923/summary.json)
reaches 43.865 us and 621 instruction-trace entries, then fails a pinned
`soc_ifc_reg` known-input assertion alongside a Veer store-buffer assertion;
it is **0/1** with no L0 pass marker. A hash-guarded copied-source probe
finds an unknown PIC interrupt input before the terminal failures. A paired
2017/2023 reducer of the pinned PIC priority tree yields Z from 32 known-zero
leaves, proving an isolated Icarus defect. The suspended PIC lane has a
[narrow cprop.cc root cause](BLOCKERS.md#caliptra-pic-packed-partial-driver-cycle--dependent-packed-partial-drivers-form-a-self-cycle)
and paired passing controls; the completed first case no longer reaches the
former terminal fatal, but its remaining error roots and full causal chain
are unproved. Repeated MLDSA/KV checker messages
are [eager consequent side effects](../../evidence/caliptra-post-aes-sva-triage-20260923/README.md)
under false property antecedents in a paired reducer; they still disqualify
the pre-PIC runtime under the zero-error rule. Strict 2017/2023 mode continues
rejecting the driver overlap.
The separate bounded Caliptra/Adams Bridge unit subset has two checked
runtime passes and one checked failure; 20/44 unit filelists compile, which
is not a DV pass count. The September 23 OpenTitan 84-row matrix has zero clean rows:
eight runtime rows finish with pass banners but retain setup/compile debt,
while the others fail compilation, fail runtime, or time out. Its rows are
not all named tests or seeds. The former 51/52 Caliptra result below used
Verilator and is not Icarus progress.
In a separate [fresh named OpenTitan smoke subset](../../evidence/opentitan-named-smokes-20260923/README.md),
xbar and pwrmgr both pass with checked scoreboard traffic (2/2 attempted);
pwrmgr uses its documented disposable checker overlay. Only xbar (1/1)
qualifies as an unmodified-source smoke in that subset. Both named images
also pass a runtime-only replay under installed VVP `e9b7a64a` with the
same scoreboard traffic; that earlier matrix was not rerun under that
binary.

The [paired guarded joint-`dist` candidate](session_logs/2026-09-23_joint_proven_guard_focus.json)
passes 22/22 focused legacy and JSON checks. The earlier post-AES local
gates passed 6,508 ordinary legacy cases plus two not-implemented and three
expected-fail cases, 131/131 VPI, 155/155 negative, 15/15 runtime,
3,442/3,442 JSON, and 358/358 real-DPI UVM. The pre-PIC [full legacy
gate](../../evidence/caliptra-final-ivtest-gate-20260924.log) passes 6,551
total: 6,546 ordinary passes, zero failures, two not implemented and three
expected failures. Bundled VPI 131/131, negatives 155/155, and VVP invariants
15/15 also pass. Pre-PIC [JSON gate](../../evidence/caliptra-final-json-gate-20260924.log) passes 3480/3480. The pre-PIC [real-DPI UVM gate](../../evidence/caliptra-final-real-dpi-uvm-20260924.log) loaded DPI but failed with 356 passes and two compile failures: `vif_smoke` and `vif_smoke_v2` each report `count` mixed drivers at line 96. The disjoint VIF property-writer false overlap received a narrow elaborate.cc repair. The shared installed candidate passes [20/20 paired dedicated cases](../../evidence/caliptra-vif-disjoint-property-writer-20260924/shared_new_focus.log) and [16/16 neighboring controls](../../evidence/caliptra-vif-disjoint-property-writer-20260924/shared_neighbor_focus.log); both VIF smokes privately compiled/ran under real DPI with `PASS counter_test` and zero UVM error/fatal. Installed iverilog/ivl/vvp SHA-256 prefixes are 1590b064/ba1dda3d/e9b7a64a. The [full shared real-DPI UVM umbrella](../../evidence/caliptra-vif-final-real-dpi-uvm-20260924.log) now passes 358/358 with zero failures/skips and both VIF smokes passing. This clean UVM regression gate is separate from Caliptra L0. The [fresh VIF-install exact unsafe first case](../../evidence/caliptra-icarus-l0-unsafe-vif-first-20260924/README.md) fails nonstandard compatibility 0/1 with 51 unrun and 17,863 diagnostics despite a pass marker and 633 retired instructions. The first [VIF-install broad legacy gate](../../evidence/caliptra-vif-final-ivtest-gate-20260924.log) failed one `sv_packed_mixed_driver_compound` expected-warning gold mismatch (6,555 total; 6,549 pass; two not implemented; three expected failures); its corrected gold passes focused legacy 1/1 and JSON 2/2. The broad rerun was intentionally stopped when independent review found a P1 unsafe virtual-dispatch called-task false waiver. A [private P1 candidate](../../evidence/caliptra-unsafe-virtual-dispatch-20260924/README.md) passed 28/28 dedicated and 34/34 neighboring controls; the installed [shared paired focus](../../evidence/caliptra-unsafe-virtual-dispatch-20260924/shared_focus.json) now passes 28/28. The P1-install broad legacy and REAL DPI UVM gates pass, as does [full JSON](../../evidence/caliptra-virtual-final-json-gate-20260924.log) 3,536/3,536; pristine compatibility review remains; [PR #350](https://github.com/dsellerbrock/iverilog-uvm/pull/350) is open. [BLOCKERS](BLOCKERS.md) records the selected narrow elaborate.cc repair. Required broader PIC qualification and error-root triage remain pending. A paired self-proof reducer
exposed and repaired an unsafe success caused by a random-dependent
distribution weight.
The pinned OpenTitan CSRNG replay still raises `UVM_FATAL` on a distinct
unresolved random guard, so it is not a DV pass. The AES focus passes 8/8
paired cases. On the pre-PIC shared install, driver focus passes 34/34,
interface-port/ref focus 28/28, and nested constant packed-select Preponed
focus 2/2 in each legacy and JSON harness. The full top has zero Preponed
sampling warnings; dynamic nested-index sampling remains unqualified. The VIF property-writer repair passes paired focus and the earlier real-DPI UVM recheck 358/358. The P1 unsafe virtual-dispatch repair now passes installed paired focus 28/28; the first broad legacy gate failed one expected-warning gold mismatch and its rerun was intentionally stopped before P1 installation. The P1-install broad legacy, full JSON 3,536/3,536, and REAL DPI UVM gates pass; pristine compatibility review, PIC error-root review, and publication remain open.

[PR346](https://github.com/dsellerbrock/iverilog-uvm/pull/346) merged after
exact-head CI success. The later CSRNG parser, solver, pinned-release overlay,
VVP loader, exact coupled distribution, and time-zero scheduler fixes are
merged in [PR348](https://github.com/dsellerbrock/iverilog-uvm/pull/348) at
`398bf5c65`. The latest
[SPI solver evidence](../../evidence/opentitan-spi-lazy-item-20260923/result.json)
records a bounded runtime stall after UVM startup. The
[CSRNG scheduler evidence](../../evidence/opentitan-csrng-timezero-scheduler-20260923/result.json)
records a repaired pre-start stall and a separate UVM_FATAL at
`cfg.randomize()`; the [paired guarded-`dist` reducer](../../evidence/opentitan-csrng-cfg-joint-dist-20260923/README.md)
isolates the next solver restriction. Neither is a DV pass. The
[post-load CSRNG reducer](../../evidence/opentitan-csrng-post-load-triage-20260923/README.md)
and [pinned overlay guide](release_overlays/README.md) bound those attempts.
The earlier [revision-scoped record](session_logs/2026-09-23_opentitan_spi_csrng_next.json)
preserves the preceding `df9f167f4` observations; it is not current
qualification. A [post-scheduler AON runtime replay](../../evidence/opentitan-aon-merged-scheduler-20260923/result.json)
passes using the earlier pinned image and current installed VVP; it is one
selected smoke, not a fresh compile or full DV. Full OpenTitan DV remains open.
The [merged-branch legacy gate](../../evidence/ivtest-broad-gate-20260923/merged-gate-result.json)
and [full JSON VVP regression](../../evidence/ivtest-broad-gate-20260923/merged-json-result.json)
pass after focused test-oracle repairs: 6,458 legacy tests with no unexplained
failures, 131/131 VPI, 155/155 negative, and 3,388/3,388 JSON. The real-DPI
UVM umbrella passed 358/358 on the pre-merge candidate; it still requires
exact-head CI confirmation for the combined branch.

The preceding focused integration was at `0a902ee9f`, following constant
unpacked-array membership support at `88f0e9044`. Its revision-scoped
[session record](session_logs/2026-09-23_inside_array_named_event_integration.json)
owns that earlier paired test and application observation. The pinned SPI Device
compile then had three kind-26 errors: two queue array-concatenation sites and
one constraint-context `inside` site. The released AON compile had zero errors,
but its smoke run timed out at 60 seconds after a `$system` warning. These are
focused compile/runtime observations, not OpenTitan DV qualification. Raw
[SPI compile](../../evidence/opentitan-spi-aon-focus-20260923/spi-device-compile.log),
[AON compile](../../evidence/opentitan-spi-aon-focus-20260923/aon-timer-compile.log),
the [AON timeout](../../evidence/opentitan-spi-aon-focus-20260923/aon-timer-smoke-timeout.log),
and a [bounded AON time trace](../../evidence/opentitan-spi-aon-focus-20260923/aon-timer-time-trace.log)
are retained. The traced run reached 416009004 ps before timing out, so the
timeout does not indicate a zero-time spin; neither earlier bounded run
produced a UVM verdict.

The preceding [scope `std::randomize` queue record](session_logs/2026-09-23_scope_queue_randomize_focus.json)
is now integrated in this tree; it covers one-dimensional local integral
queues with exactly constrained lengths through 65536 elements, including
declared maxima. Earlier reports of eight later vector-context diagnostics
are superseded by the current pinned SPI replay recorded above.

The preceding [associative statement-method focus](session_logs/2026-09-23_assoc_queue_statement_methods_focus.json)
is on `d0560368e`; its follow-on PR, broad gates, and application DV qualification remain
open. The [OpenTitan `find_index` and multi-object event record](session_logs/2026-09-23_opentitan_assoc_find_index_multi_object_focus.json)
merged in [PR341](https://github.com/dsellerbrock/iverilog-uvm/pull/341) at
`7943dffd1` after exact-head Ubuntu 24.04 success. PR340 merged at `909e3f314`
after exact-head Ubuntu 22.04 success; its [class-event `.triggered` record](session_logs/2026-09-23_opentitan_class_event_triggered_focus.json)
preserves the scoped evidence. The PR341 UCRT64 checkout stopped at certificate
trust before invoking the compiler.

The [PR339 compiler and VPI repair record](session_logs/2026-09-23_spi_adc_pr339_repair_focus.json)
links the package-parameter `foreach`, packed-struct queue `.size`, direct
unbased-fill cast, caller-queue, and VPI callback corrections to local gates
and a fresh pinned SPI Device compile. PR339 merged at `6fd804a39` after its
Ubuntu 24.04 exact-head check passed; SPI Device, ADC, and full application DV
remain unqualified.

The [parallel compiler follow-on record](session_logs/2026-09-23_parallel_compiler_followon_focus.json)
links locally integrated ADC outer resize, SPI Device sparse-key constraint
`foreach`, and VPI force/release statement-object checks on the branch after
[PR338](https://github.com/dsellerbrock/iverilog-uvm/pull/338) merged. Indexed
ADC inner sizes, full SPI Device DV, broad suites, and this branch's CI remain
open.

The [latest pinned Caliptra L0 replay](../../evidence/caliptra-l0-52-and-full-dv-gap-20260923/full_l0_summary.json)
records 51/52 selected passes with the two test-specific firmware overlays;
DOE scan alone remains failed on an intact assertion. The earlier
[exact-toolchain baseline](../../evidence/caliptra-exact-l0-20260923/README.md)
was 49/52. A [single CSRNG unit runtime](../../evidence/caliptra-csrng-unit-runtime-20260923/README.md)
passes its explicit checks after a disposable filelist-order and include-path
correction, while emitting unique-case warnings; the full DV suite remains
unqualified.

The [DOE passive timing trace](../../evidence/caliptra-doe-root-cause-20260923/assessment.md)
confirms that Verilator retains a pre-reset `|=>` attempt that IEEE `disable iff`
requires it to abort; no fresh post-reset antecedent was sampled. The earlier
[source diagnosis and restored Verilator recheck](session_logs/2026-09-23_caliptra_doe_verilator_defuture_blocker.json)
identify the defutured implication mechanism. The intact DOE test remains a
strict L0 failure until a corrected simulator passes it without SVA errors.

The [Caliptra KV SVA diagnostic overlay replay](session_logs/2026-09-23_caliptra_kv_sva_overlay_l0.json)
is scoped to pinned Caliptra `v2.1.2` and Verilator. It removes false-antecedent
inner diagnostics while retaining detailed failure output; this is diagnostic
evidence with a RISC-V multilib caveat, not full L0 or Caliptra DV qualification.

The [ADC guarded-distribution and OpenTitan fileset record](session_logs/2026-09-23_opentitan_adc_guarded_dist_fileset_focus.json)
is scoped to solver and matrix commits `4e14d8dde`/`e94e25e37`. The focused
checks preceded their rebase onto merged PR336; relevant source and tests are
byte-identical after the rebase. The guarded large-range `dist` correction
passes paired 2017/2023 focused checks (4+4) and neighboring distribution
checks (36+36). The pinned ADC smoke now gets past the exact-distribution
resolver but still fails at time 0 because global randomization cannot resize
its nested dynamic array; this is not a DV pass. The matrix runner now
selects generated RTL filesets, and focused pinmux setup compiles. The full
OpenTitan matrix was not rerun.

The [case-exit stack balance record](session_logs/2026-09-23_pwrmgr_case_exit_stack_balance.json)
links the focused compiler checks to the pinned released OpenTitan pwrmgr replay:
all named pwrmgr tests at seed 1 and smoke seeds 1–6 retain matched TL scoreboard
traffic, with the earlier cleanup diagnostics removed. This is a frozen
generated-source snapshot with the documented checker overlay and remaining
compile warnings, not the full release DV suite. A fresh full OpenTitan and
Caliptra DV inventory and failure census are active separately.

The [integrated focus record](session_logs/2026-09-23_vpi_macro_integrated_focus.json) covers the matched-bracket macro correction and VPI variable-bit force/release callback rejection merged in [PR335](https://github.com/dsellerbrock/iverilog-uvm/pull/335). Paired and neighboring tests pass; Ubuntu 24.04 exact-head CI succeeded after the merge. The [macro baseline](../../evidence/macro-bracket-assessment-20260923/README.md) preserves the original failures.

The [Caliptra long-sequence register fix](session_logs/2026-09-23_caliptra_long_sequence_register_focus.json) at `4ff0581df` passed executable and neighboring checks before integration. On the [locally integrated tree](session_logs/2026-09-23_caliptra_pm_integrated_compile.json), the clean pinned PM formal filelist compiles without diagnostics in both editions and the long-sequence focus passes. The fix merged in [PR335](https://github.com/dsellerbrock/iverilog-uvm/pull/335); this is formal-file compile evidence only, with full DV and formal proof still open.

The [Caliptra late-default-clocking record](session_logs/2026-09-23_caliptra_late_default_clocking_focus.json) covers paired 2017/2023 checker execution and rejection boundaries on source/test commit `342226068`; the pinned clean ECC formal compile moves past five false clock diagnostics but still fails at a separate `DSA_NOP` binding error. A [one-token, test-specific released-source overlay](session_logs/2026-09-23_caliptra_ecc_nop_overlay.json) makes that filelist compile in a disposable copy; no formal proof or DV runtime is claimed. [PR334](https://github.com/dsellerbrock/iverilog-uvm/pull/334) merged after Ubuntu 24.04 exact-head CI passed.

The [pinned OpenTitan ADC macro-argument baseline](session_logs/2026-09-23_opentitan_adc_macro_arg_baseline.json) isolates the first `adc_ctrl_sim` compile error to `ivlpp` scanner nesting around a cast. The [focused candidate](session_logs/2026-09-23_opentitan_adc_macro_arg_focus.json) compiles the same generated release source list on source/test commit `284a4c65d`, but an ignored filter-size constraint and a separate cast-width runtime defect prevent a semantic compile or DV-pass claim. No ADC smoke ran.

The [named-antecedent Caliptra ECC record](session_logs/2026-09-23_caliptra_named_sequence_antecedent.json) covers a one-step declared sequence ahead of an instance-sized symbolic consequent. Paired 2017/2023 executable checks and the pinned full ECC formal bind compile passed locally on `312eff1af`; this subset merged in [PR333](https://github.com/dsellerbrock/iverilog-uvm/pull/333) after an exact-head CI success. Multi-step antecedents and full Caliptra DV/formal qualification remain open.

The [fixed SVA overlap and VPI attempt-identity record](session_logs/2026-09-23_sva_literal_overlap_attempt_identity.json) covers separate same-edge failure verdicts, four-state nonmatches, and exact callback start times in the fixed linear checker. Paired-edition reducers and required local gates passed on `e54b76124`; this subset merged in [PR332](https://github.com/dsellerbrock/iverilog-uvm/pull/332) after an exact-head CI success. Window, unbounded, and negated checker metadata, full SVA, and application DV remain separate.

The [Caliptra consequent-repetition candidate](session_logs/2026-09-23_caliptra_param_consequent_repeat_focus.json) records paired-edition executable assertion checks and a pinned formal-file compile with no dropped repeat properties; the [baseline](session_logs/2026-09-23_caliptra_param_consequent_repeat_baseline.json) preserves the original failure. It passed its required local gates and merged in [PR330](https://github.com/dsellerbrock/iverilog-uvm/pull/330) after exact-head CI success, following [PR329](https://github.com/dsellerbrock/iverilog-uvm/pull/329). The standalone bind-target error and full Caliptra DV/formal qualification remain separate.

The [released pwrmgr replay](session_logs/2026-09-23_pwrmgr_release_overlay_current.json) records seed-1 and seed-3 smoke passes with observed TL traffic on a frozen pinned-release source snapshot and the checker overlay. The [release profile](release_overlays/README.md) names the required compiler-command-file timescale; this documentation correction merged in [PR331](https://github.com/dsellerbrock/iverilog-uvm/pull/331). It does not establish full OpenTitan DV qualification.

The [class-property queue-pop candidate](session_logs/2026-09-23_opentitan_queue_pop_focus.json) at `a0e45a3c7` has passing paired focused tests and a pinned SPI Host compile with no queue-pop drop. A [review boundary follow-up](session_logs/2026-09-23_queue_pop_assoc_boundary.json) at `3b6d1986f` rejects queue-only pops on associative arrays in expression context while preserving queues stored inside them. This subset merged in [PR329](https://github.com/dsellerbrock/iverilog-uvm/pull/329). [Statement-context calls remain incorrectly accepted](session_logs/2026-09-23_assoc_queue_pop_statement_debt.json) and are tracked separately. Four unresolved constraint-index warnings still prevent a semantic SPI compile or DV-pass claim.

The earlier [OpenTitan selected-bit NBA and task-error candidate](session_logs/2026-09-23_opentitan_nba_codegen_focus.json) merged in [PR328](https://github.com/dsellerbrock/iverilog-uvm/pull/328) at `4f66ed666`. Its local validation and earlier SPI compile remain scoped to that source. Four unresolved constraint indices and a later queue-pop candidate still delimit the SPI result; the correctly configured fixed-seed smoke passed the earlier time-zero regex barrier and aborted on a VIF event-relay runtime form at 3,673,793 ps. The target-specific [release overlay profiles](release_overlays/README.md) define the pinned application sources, patch selection, and observed run options.

The opt-in `-gcommercial-unsafe` mode merged in [PR326](https://github.com/dsellerbrock/iverilog-uvm/pull/326) at `fa5ae6da5` (source commit `9111127532c71fc4eeaf1bab68685ade3c61296f`). Its [focused flag checks](session_logs/2026-09-23_commercial_unsafe_flag.json) and [post-merge local qualification](session_logs/2026-09-23_pr326_postmerge_qualification.json) are separate records: the latter passed the required compiler/ivtest/SVA and real-DPI UVM gates on a compiler/test tree identical to merged `main`; CI was pending at observation. The flag alone cleared strict SPI type errors but left the selected-bit NBA target errors later addressed by the current candidate. OpenTitan DV has not passed.

The [Caliptra `rej_bounded` race fix](session_logs/2026-09-23_caliptra_rej_bounded_race_fix.json) has a separately tested, minimal [Adams Bridge testbench patch](repros/caliptra_rej_bounded/README.md), now proposed in [upstream PR 303](https://github.com/chipsalliance/adams-bridge/pull/303). The pinned releases remain unmodified and failing; the patched-copy result is focused application evidence, not full Caliptra DV qualification.

The earlier [scalar caller-state X/Z port](session_logs/2026-09-23_constraint_state_xz_port.json) passed its required local runtime gates on source/test commit `527c0930a` and merged in [PR325](https://github.com/dsellerbrock/iverilog-uvm/pull/325) at `7044ae62c` after Ubuntu 22.04 CI passed. The known wide caller-state truncation is recorded in [DISCOVERED_DEBT](DISCOVERED_DEBT.md); it is not part of the X/Z scope.

The [branch reconciliation](session_logs/2026-09-23_pr322_branch_reconciliation.json) records that PR322 closed without a merge while its independent fixes were committed directly to `main`. The missing fixed-array element guard and caller-boundary regressions merged in [PR324](https://github.com/dsellerbrock/iverilog-uvm/pull/324) at `ea0be16d5`; its [exact-source local qualification](session_logs/2026-09-23_pr322_reconciliation.json) is preserved, while PR324 CI was still running at this checkpoint. PR323's guarded inline-function path covers the caller-method tests, and PR322's bypassing shortcut was removed. That checkpoint still had queue-element type errors and no SPI DV pass; the newer flag result is linked above.

The earlier [inline constraint state-function candidate](session_logs/2026-09-23_inline_state_function_focus.json) records the state-only scope now merged in PR323. Random-variable actual arguments and wide results remain open. The [MSYS2 strict-regex fix](session_logs/2026-09-22_win_regex_tre_fix.json) merged in PR321; its prior pending-CI note is historical.

The [caller-owned queue foreach candidate](session_logs/2026-09-22_caller_queue_foreach_focus.json) records passing required local gates and removal of the corresponding pristine SPI compile error. It merged as PR320 (`1af223c8`); independent SPI errors remain.

The [until continuation candidate](session_logs/2026-09-21_until_continuation_focus.json) records the compiler correction and passing required local validation. It merged as [PR319](https://github.com/dsellerbrock/iverilog-uvm/pull/319) (`288132f2`); Ubuntu and macOS CI passed and all three MSYS2 jobs failed only `uvm_regex_strict_exec_test`. Broader assertion and application qualification remains open.

The [selected-VIF edge candidate](session_logs/2026-09-21_selected_vif_edge_focus.json) records the current compiler patch, passing required local gates and stable-release application replays. Merged in [PR318](https://github.com/dsellerbrock/iverilog-uvm/pull/318) as `ca29b1237` after both Ubuntu CI jobs passed; remaining platform checks were still running.

The [seed-3 upstream revalidation](session_logs/2026-09-21_pwrmgr_seed3_upstream_revalidation.json) confirms valid stimulus and an upstream checker defect, separately validates the minimal checker overlay, and records the stronger backport's uncovered `until` continuation gap. Patched results do not qualify the pristine release.

The [SPI class event-list checkpoint](session_logs/2026-09-21_spi_class_event_list_focus.json) records paired-edition semantic tests and mapped UVM validation. Pristine SPI Host still fails compilation; this is not application qualification.

The [current-build seed-3 recheck](session_logs/2026-09-21_pwrmgr_seed3_current_build_recheck.json) reconfirms the corrected checker passes and the pristine release fails, with unchanged corpus and recorded dirty compiler-patch provenance.

The [seed-3 checker correction](session_logs/2026-09-21_pwrmgr_seed3_checker_fix.json) records a separately patched upstream checker, passing seed1/seed3 smoke, and retained stopped-clock failure checks. The pristine release stays unchanged and its seed3 remains failing; this is patched-DV evidence.

The [pwrmgr seed-3 assessment](session_logs/2026-09-21_pwrmgr_seed3_phase_assessment.json) identifies a clock-phase assumption in the unchanged upstream assertion. The run remains failing; this is diagnostic evidence, not an application pass or a compiler fix.

Latest focused candidate: [whole-function class event expressions](session_logs/2026-09-21_whole_function_event_focus.json). Permanent harnesses and all required local gates pass; publication/CI remain pending. The merged compiler baseline is PR315 (`175dcb65d`), with [occurrence-time event qualification](session_logs/2026-09-21_occurrence_event_focus.json); earlier pending publication notes are superseded. Full application DV qualification remains open.

Fresh [unmodified stable-release replays on this candidate](session_logs/2026-09-21_whole_function_event_applications.json) preserve the known passing and failing cases; compiler qualification remains pending.

Latest compiler qualification: [PR312 required local gates](session_logs/2026-09-21_pr312_local_qualification.json) pass on repair source `0b1aeaee6`, identical to `b5bc2864f` for compiler/test inputs. CI remains pending. This supersedes pending local-gate statements below; application outcomes retain their recorded provenance.

Latest PR309 evidence: [required local qualification](session_logs/2026-09-21_pr309_local_qualification.json) passes on `09316da3d`; PR309 merged as `cb6f35b56` while CI was still running. This supersedes the earlier pending-local-gate notes below without changing their historical results or claiming full application qualification.

Documentation checkpoint: **2026-09-14**, reviewed against `main` revision
`9c8f716b1`; operational handoff reconciled after documentation merge
`fdbb8f34a` and local sync `3ab991187`. This page points to recorded evidence; it does not claim a fresh
run on every later checkout.

## September 20 merged-baseline restoration

The [restoration record](session_logs/2026-09-20_merged_baseline_restoration.md)
identifies source/test changes missing after the three PR merges and the
reviewed checkpoint used to restore them. The local qualification is linked below.

## September 20 integration review

The [PR review and repair record](session_logs/2026-09-20_pr_review_repairs.md)
identifies the three reproduced defects and their repairs. PR306 restored
the reviewed compiler/test tree to main. Resumption and
validation state belong to ACTIVE_WORK and CAMPAIGN linked below.

## Latest merged baseline

[PR308 merge record](session_logs/2026-09-21_pr308_merge.json): main is `482c3c89d`, with the nine-fix locally qualified batch merged after both Ubuntu CI jobs passed. Four other jobs were still running at observation. The [PR307 record](session_logs/2026-09-21_pr307_merge.json) retains the preceding baseline.

## Current focused implementation

The [port regression repair](session_logs/2026-09-21_port_regression_repair.json) removes the unnecessary behavioral carrier and preserves structural propagation. Shared qualification remains pending the event repairs.

The [six-fix installed focus](session_logs/2026-09-21_shared_six_focus.json) records the shared rebuild and passing permanent regressions. The [broad gate failed](session_logs/2026-09-21_shared_six_gate_failure.json), so qualification is pending repair. The [fresh stable-release replay](session_logs/2026-09-21_shared_six_release_retest.json) records current application results.

The [variable-output review](session_logs/2026-09-21_variable_output_integration_review.json) records private semantic and integration checks; shared qualification is pending.

The [Caliptra boundary trace](session_logs/2026-09-21_caliptra_rej_boundary_trace.json) records evidence for the remaining testbench scheduling race; the test still fails.

The [private Caliptra string replay](session_logs/2026-09-21_caliptra_string_private_replay.json) records progress past filename/vector generation and the remaining scoreboard failure. It is candidate evidence, not an integrated application pass. The [synthesis review](session_logs/2026-09-21_caliptra_string_synthesis_review.json) records the corrected candidate and its replay.

The [scope solver UNKNOWN repair](session_logs/2026-09-21_scope_solver_unknown_fix.json) is focused-tested on the next-batch branch. The [long fixed antecedent repair](session_logs/2026-09-21_long_fixed_antecedent_fix.json) is also focused-tested. Broad next-batch qualification is pending; both fixes are separate from PR307.

The [constraint object-method repair](session_logs/2026-09-21_constraint_object_method_receiver.json) has paired focused and neighboring regression evidence; broad batch gates remain pending.

The [bare enum-name repair](session_logs/2026-09-21_enum_bare_name_type.json) has paired focused and enum-neighbor evidence, pending broad batch gates.

The [self-package cast repair](session_logs/2026-09-21_self_package_type_cast.json) and [signed coverage range repair](session_logs/2026-09-21_signed_cover_range_resolution.json) have paired focused evidence. Required broad batch gates remain pending.

The [pwrmgr startup replay](session_logs/2026-09-21_pwrmgr_startup.json) reaches runtime but fails HDL-path checking; compiler fallback warnings also exclude application qualification.

The [nine-fix checkpoint release retest](session_logs/2026-09-21_batch_nine_release_retest.json) records fresh stable-source application results and the current broad-gate failure. Full batch qualification remains pending.

## Latest recorded compiler qualification

The [nine-fix batch qualification](session_logs/2026-09-21_nine_fix_batch_qualification.json) records all seven required local gates passing on semantic revision `c1635efe9`, including the synthesis metadata repair. CI, private next-batch candidates, and full application/standards qualification remain separate.

The [next-candidate release retest](session_logs/2026-09-21_next_candidate_release_retest.json) preserves earlier bounded OpenTitan and Caliptra runtime results, including source/binary fingerprints and clean release pins. It does not qualify the pending compiler patches. The [published-candidate retest](session_logs/2026-09-21_published_candidate_release_retest.json) and September 20 static census remain revision-scoped historical evidence.

The [canonical graph and cleanup record](session_logs/2026-09-21_canonical_graph_cleanup.json) records the restored main checkout, shared graph refresh, retired worktree, preserved branch, and cleanup audit.

The [September 21 batch qualification](session_logs/2026-09-21_compiler_batch_qualification.json) records all seven local gates passing for semantic revision `8ab943352`. It supersedes the earlier batch checkpoints below for local compiler validation; GitHub CI and application revision limits remain separate.

The [restored-baseline qualification](session_logs/2026-09-20_restored_baseline_qualification.json)
records all seven local gates passing for semantic revision `e90059a07`,
whose compiler/test tree matches merged main `0998f058a`. Counts, commands,
artifact fingerprints and edition limits live in that record. GitHub CI
remains separate from this local evidence.

The earlier [L96–L105 qualification](session_logs/2026-09-15_compiler_batch_l96_l105_qualification.json)
and [batch session](session_logs/2026-09-15_compiler_batch_l96_l105.md)
retain their revision-scoped results.

This qualifies that local candidate, not full IEEE, UVM or whole-application
support. Earlier [L85–L95](session_logs/2026-09-15_compiler_batch_l85_l95_qualification.json),
[L75–L84](session_logs/2026-09-14_compiler_batch_l75_l84_qualification.json),
[L65–L74](session_logs/2026-09-14_compiler_batch_l65_l74_qualification.json)
and [L64](session_logs/2026-09-14_constraint_function_presolve_qualification.json)
records retain their original revisions and limits.

## Application evidence

The [type-first candidate release retest](session_logs/2026-09-21_typed_candidate_release_retest.json)
records the later candidate fingerprints, fresh unmodified release runtime results,
remaining GPIO failure, and cleanup disposition. This bounded run does not qualify
the pending compiler batch.

The [September 21 bounded release retest](session_logs/2026-09-21_stable_release_retest.json)
records fresh compiler/runtime fingerprints, unmodified Caliptra unit and OpenTitan
peripheral-crossbar results, GPIO failure, and cleanup. It covers the recorded
uncommitted candidate; it does not qualify the pending compiler batch.

The [September 20 stable-release replay checkpoint](session_logs/2026-09-20_stable_release_replay.json)
records the fresh Caliptra static census and unmodified power2round unit-runtime
pass with warnings, unmodified OpenTitan TL-agent and Earlgrey xbar UVM test
verdicts with a runtime warning, the completed census, and audited cleanup. These bounded
results do not establish full-chip or complete application qualification.

The [September 15 OpenTitan `xbar_smoke` UVM pass](session_logs/2026-09-15_opentitan_xbar_smoke_patched.md)
is the first UVM test to reach `TEST PASSED CHECKS` against a stable OpenTitan
release (Earlgrey-PROD-M6). **It is a patched-release result, not an
unmodified-source pass** — one `dv_report_catcher.sv` source correction was
required for a nonstandard `foreach` spelling (upstream syntax defect, not an
Icarus gap; see the log for the IEEE 1800 §12.7.3 citation). The original,
unmodified file's failure is preserved, not overwritten.

The [September 13 OpenTitan/Caliptra census](session_logs/2026-09-13_opentitan_caliptra_rebaseline_after277.md)
is scoped to `631bba6e8`. It predates L43–L64 and is not an application replay
of the newer compiler. It includes failures and dependency/configuration debt;
completion of the census is not application success.

The [UVM release matrix](uvm_release_matrix.md) owns library acquisition and
release-smoke interpretation. The [2017 clause matrix](matrices/ieee1800_2017_clause_matrix.md)
and [2023 survey](ieee1800_2023_delta.md) own standards dispositions.

## Work selection and resumption

- [BLOCKERS](BLOCKERS.md): operational backlog and blocker status.
- [ACTIVE_WORK](../../.ai/ACTIVE_WORK.yaml): selected implementation ticket.
- [CAMPAIGN](../../.ai/CAMPAIGN.yaml): operational handoff, exact next command,
  and pending work. Check its revision before resuming; it may lag committed
  qualification evidence.
- [DISCOVERED_DEBT](DISCOVERED_DEBT.md): observations awaiting triage.
- [AGENTS](../../AGENTS.md): workflow, toolchain, and validation requirements.

The campaign owner reconciled the handoff with the final L64 JSON linked above.
The earlier operational record is preserved in the
[handoff archive](session_logs/2026-09-14_campaign_handoff_archive.yaml).
L64 was published in [PR280](https://github.com/dsellerbrock/iverilog-uvm/pull/280)
and externally merged as `5c0f5588e`; this does not turn its local qualification
into cross-platform qualification.

[PR281](https://github.com/dsellerbrock/iverilog-uvm/pull/281), externally merged
as `9c8f716b1`, repairs build defects exposed by that publication. Its current revision, CI state, and exact next
command belong to CAMPAIGN. The post-L64 batch is locally qualified by the
latest record above. Publication status and subsequent work remain in CAMPAIGN.
No newer whole-application replay is claimed.

## History

The former continuation narrative is preserved in the
[July–September archive](session_logs/2026-09-14_current_work_archive.md).
Earlier checkpoints and failed attempts remain in the
[session logs](session_logs/README.md). Keep historical results revision-scoped;
update these pointers when new evidence is committed.

The [grouped clocked consequent record](session_logs/2026-09-20_grouped_clocked_consequent.md) provides focused paired-edition evidence pending the next batch qualification.

The [masked memory synthesis record](session_logs/2026-09-20_masked_memory_synthesis.json) contains the next paired focused checkpoint, pending batch qualification.

The [variable-row assignment record](session_logs/2026-09-20_variable_row_assignment.json) contains paired focused evidence and the remaining Ibex synthesis boundary.

The [state-selected constraint record](session_logs/2026-09-21_state_selected_fixed_array_constraints.json) tracks the next paired focused candidate and its validation status.

The [reset-only synthesis record](session_logs/2026-09-21_reset_only_synthesis.json) records the next paired runtime checkpoint.

The [restoration CI checkpoint](session_logs/2026-09-21_restoration_ci_checkpoint.json) records live exact-head platform status for PR306, independently of the current batch.

Latest bounded application retest: [queue-validity candidate release evidence](session_logs/2026-09-21_queue_candidate_release_retest.json). This does not supersede full compiler qualification.

The [constraint cast/distribution checkpoint](session_logs/2026-09-21_constraint_cast_distribution_checkpoint.json)
records focused and neighboring regression evidence for `969853350`, pending broad batch qualification.

The [September 21 candidate release retest and cleanup](session_logs/2026-09-21_candidate_release_retest_and_cleanup.json)
records fresh pinned-release application results and disposable binary removal.
It does not qualify the current uncommitted compiler candidate.

The [synthesis and wide-index focused checkpoint](session_logs/2026-09-21_synthesis_and_wide_index_focus.json) records paired-edition runtime and neighboring-test evidence. Required broad batch gates remain pending.

The [repaired-candidate release retest](session_logs/2026-09-21_repaired_candidate_release_retest.json) supersedes the earlier application snapshot for the latest elaboration repairs. Full batch qualification remains pending.

The [empty-branch enable repair](session_logs/2026-09-21_empty_branch_enable_repair.json) records the JSON-discovered synthesis regression and focused recovery; the final broad run is tracked in CAMPAIGN.

Latest bounded release replay: [2026-09-21 current candidate](session_logs/2026-09-21_current_release_retest.json). Exact pins, commands, runtime outcomes and qualification limits are recorded there.

Latest packed-VPI local checkpoint: [paired tests and affected-suite evidence](session_logs/2026-09-21_packed_vpi_integration.json). Broad batch qualification remains pending.

The [constraint divide/remainder error repair](session_logs/2026-09-21_constraint_divmod_zero.json) has paired focused and neighboring runtime evidence; broad batch gates remain pending.

The [joint ordered-randc repair](session_logs/2026-09-21_joint_ordered_randc.json) has paired runtime, distribution and rollback evidence; batch gates remain pending.

Latest bounded stable-application replay: [qualified nine-fix candidate](session_logs/2026-09-21_qualified_nine_release_retest.json). Exact corpus pins, binary fingerprints, commands, pass/failure evidence and scope limits are in that record.

Draft review checkpoint: [PR #309](https://github.com/dsellerbrock/iverilog-uvm/pull/309) publishes `b03bccdf9` for review. It is not a qualified baseline; the PR lists the preserved local regression failures and required repair/requalification. Current private repair lanes and the uncommitted automatic-context integration are recorded in `.ai/CAMPAIGN.yaml`.

[Event runtime repair checkpoint](session_logs/2026-09-21_event_runtime_regression_repair.json) supersedes the runtime failure status above for its recorded source/tools. Synthesis repairs and broad requalification remain pending; PR #309 stays draft.

[Synthesis event repair evidence](session_logs/2026-09-21_synthesis_event_regression_repair.json) records the successful replay of all earlier failing legacy/VPI cases and new paired boundary tests. [Fresh pinned release replay](session_logs/2026-09-21_repaired_release_replay.json) and [initial PR309 CI classification](session_logs/2026-09-21_pr309_initial_ci.json) preserve application limitations and the Windows export repair. Full repaired-revision gates are pending.

The [OpenTitan regex trace](session_logs/2026-09-21_opentitan_regex_attribution.json) attributes the current GPIO/pwrmgr startup errors to a direct glob-shaped argument reaching the strict legacy regex API. It establishes no application pass or new compiler fix.

The [OpenTitan crossbar expansion](session_logs/2026-09-21_opentitan_crossbar_expansion.json) records the upstream zero-delay variant pass and random-test timeout without workload reduction. It does not qualify the full suite.

The [PR309 CI checkpoint](session_logs/2026-09-21_pr309_ci_checkpoint.json) records Ubuntu 24.04 success on the merged compiler revision; remaining platforms were still running at capture.

Latest SPI Host compiler checkpoint: [fixed member-array constraint evidence](session_logs/2026-09-21_spi_host_member_array_focus.json). Required broader checks and application blockers remain explicit in the record.

The [OpenTitan configuration correction and replay](session_logs/2026-09-21_opentitan_regex_configuration.json) supersedes the earlier no-configuration-mismatch conclusion. Application qualification remains limited as recorded there.

[Dependency-kind regression repair](session_logs/2026-09-21_spi_host_dependency_kind_repair.json) records the broad-gate failures and focused recovery for PR311; broader requalification remains pending.

PR #311 merged externally before the dependency-kind repair. The [follow-up integrated record](session_logs/2026-09-21_dependency_kind_integrated_followup.json) records the repaired source and passing integrated gate; remaining qualification is tracked in CAMPAIGN.

The [power-manager descendant VIF checkpoint](session_logs/2026-09-21_pwrmgr_descendant_vif_focus.json) records paired focused runtime tests and the next pinned application boundary. Broad qualification for this new increment remains pending.

The current large-range distribution candidate and GPIO traffic evidence are recorded in [the 2026-09-21 focus checkpoint](session_logs/2026-09-21_exact_large_dist_focus.json). All required local gates passed on the recorded frozen source; CI awaits publication.
