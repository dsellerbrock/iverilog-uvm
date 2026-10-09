# OpenTitan hot-path optimization plan

Source-backed profile and census evidence is in
[HOTPATHS.md](../../evidence/opentitan-census-20261002/census12-full-corpus-20261003/HOTPATHS.md).
Bounded reproducers and measurements are in
[benchmarks/opentitan-hotpaths](../../benchmarks/opentitan-hotpaths/README.md).
Profiles are phase snapshots with overlapping inclusive counts, not whole-run
CPU percentages.

General (non-OpenTitan) runtime hot spots — vector functors, call-frame
bookkeeping, virtual dispatch, and design load — and their measured fixes are
recorded in [benchmarks/sim-hotspots](../../benchmarks/sim-hotspots/README.md).

## Prioritized plan

The Flash associative-array successor index is implemented. The 262,144-key
VVP reproducer passes three times, the isolated seven-operation Flash run is
37.6% shorter (1.60x), and the post-change selected OpenTitan census passes
[49/49](../../evidence/opentitan-census-20261002/census14-post-vector-aa-index-20261004/README.md).
Remaining paths below need their own measured optimizations.

The Flash `read32()` candidate now has a real-UVM reproducer and a four-to-one
VPI-call reduction; its paired microbenchmark is 62% faster. The OpenTitan
source patch is still pending a focused full-test replay, so this result does
not qualify an end-to-end Flash speedup. See the [reproducer and patch record](../../benchmarks/opentitan-hotpaths/flash_read32.md).

| Path | First speedup step | Risks and minimum validation |
| --- | --- | --- |
| **Flash associative-array next** | **Implemented:** retain the raw-key `std::map` for exact identity and lazily build a pointer-only ordered index per signedness mode. `upper_bound` makes each successor lookup O(log N); the full walk is O(N log N) after index construction. The real VVP `.first/.next` fixture covers 262,144 keys. Hash-only lookup cannot return an ordered successor; hash plus tree was slower than the tree alone in the C++ microbenchmark. | Preserve signed/unsigned ordering, sign extension, four-state order, and raw-width identity. Keep the index live across insert/delete and invalidate it on copy/clear. Both order modes, 0/1/X/Z, absent keys, distinct-width identities, mutation, and copy/clear are covered by the implementation regressions. The C++ standard guarantees logarithmic ordered-container lookup; Pugh's skip list is an academically studied alternative, not evidence of a VVP speedup: [ordered-container requirements](https://eel.is/c++draft/associative.reqmts), [Pugh, Skip Lists](https://doi.org/10.1145/78973.78977). |
| **Flash backdoor population** | Add an opt-in packed-word read for the Flash layout, reducing up to four byte-level HDL reads per read32 to one. | Check alignment, byte order, data/ECC mapping, X/unknown behavior, and virtual overrides. Compare packed reads to the current four-read reference at boundaries; measure VPI calls and model-build time. [OpenTitan memory backdoor docs](https://opentitan.org/book/hw/dv/sv/mem_bkdr_util/index.html). |
| **Sparse-wide Z3 enumeration** | Instrument solver checks, model extraction, blockers, support size, cap fallback, and time per randomize. Specialize only provable small finite sets or bounded intervals. | Preserve exact feasible support and distribution semantics; approximate model sampling is not equivalent. Compare feasible sets, seeded behavior, and weights for sparse, coupled, and over-cap cases. Z3's own guide notes that blocking lemmas accumulate and shows a scoped All-SMT alternative; newer projected-enumeration algorithms require solver changes and are not drop-in SV samplers: [Programming Z3, blocking evaluations](https://z3prover.github.io/papers/programmingz3.html#sec-blocking-evaluations), [Phan et al.](https://doi.org/10.1109/ARES.2015.14), [Spallitta et al.](https://doi.org/10.1016/j.artint.2025.104346). |
| **RV-DM joint Z3 tuples** | Measure separately from sparse domains. Factor disconnected variable components only after proving independence; this may avoid enumerating a Cartesian product. | Preserve tuple support, multiplicity/weights, sort order, cap behavior, and exclude auxiliary variables. Compare exact tuples and frequencies on independent and coupled models. General All-SMT work does not establish SV randomization equivalence here. |
| **SRAM indexed VPI lookup** | Cache successful `(scope, name) → array handle` resolutions; if profiles show broad scans, consider a per-scope name hash index. Hashing fits exact name lookup, unlike ordered successor queries; unordered lookup is average O(1), worst-case O(N). | Preserve cache lifetime and escaped-name behavior. Compare handles and values for indexed arrays, ranges, packed selections, escaped identifiers, and misses; count `find_name`, `get_word_str`, and fallback calls. See [unordered-container requirements](https://eel.is/c++draft/unord.req.general). |
| **SVA/VPI dispatch** | Reduce wrapper work around the existing (scope,index) hash. Resolve stable call-site IDs/handles once or lower them to a direct runtime operand where valid. | Preserve automatic-scope identity, handle lifetime, and multiclock $assertkill generations. Count iterator/get/scope lookups per callback; run assertion-control stress, selective labels, and multiclock kill/restart cases. Use the [IEEE 1800 VPI contract](https://standards.ieee.org/ieee/1800/7743/) as the semantic authority. |
| **Object/context/liveness** | Count probes first. If owner and live-state checks dominate, combine them into one context record. If notifications greatly outnumber subscriptions, consider immutable copy-on-write alias snapshots. | Preserve callback-time registration changes, teardown, pointer reuse/generation, and destruction order. Test reentrant subscribe/unsubscribe and automatic-context teardown/reuse; measure fanout and copied bytes. Registries already use hash containers, so hashing alone is not an optimization plan. |
| **Four-state conversion/resolution** | Try packed conversion or a small lookup table to reduce per-bit conversion and setter calls. This is a constant-factor change, not a complexity change. | Exhaustively compare four/eight-state and drive-strength combinations against the existing resolver, then measure wide buses. Preserve X/Z and strength behavior. |
| **Virtual-interface slot resolution** | First compare member names before RTTI checks. If repeated construction still dominates, build a per-scope name/type index once. | Check signals, arrays, reals, strings, objects, and missing properties. Count scope entries and RTTI calls across repeated construction; this is startup-only and ranks below sustained paths. |
| **Standard distribution randomization** | Instrument branch construction, solver checks, allocations, and fallback. Reuse immutable normalized branch metadata; consider direct exact weighted sampling only for proven fixed supports. | Preserve := versus :/, signed sizing/clipping, constraint coupling, and random-stream use. Exhaustively compare small-domain support and weights before timing. Vose's alias method gives linear table construction and constant-time draws for a fixed finite distribution, but its applicability and exact integer-weight behavior must be established: [Vose, A Linear Algorithm for Generating Random Numbers with a Given Distribution](https://doi.org/10.1109/32.92917). It does not establish equivalence for SystemVerilog constraints or this VVP path. |

## Implementation and acceptance gates

The AA entry above is complete. Its oracle checks comparator ordering and actual
VVP `.first/.next` traversal; the 262,144-key fixture and isolated Flash replay
show measured results in the [benchmark record](../../benchmarks/opentitan-hotpaths/README.md).
For the remaining entries, treat the following algorithmic effects as design
hypotheses until the named counters and same-input timing demonstrate a gain.

| Order | Change and expected work | Minimum semantic oracle | Measure and proposed promotion gate |
| --- | --- | --- | --- |
| 1 | **Flash reads:** 4 HDL reads per `read32` → 1 packed read when the Flash layout allows it. | Byte/ECC equality against the four-read reference at alignment and partition boundaries; preserve virtual overrides and X handling. | HDL read count and scoreboard-build time. Promote if reads approach 1/word and same-input model-build time improves. |
| 2 | **Sparse Z3:** current complete support enumeration makes O(K) check/model/blocker iterations for K feasible values. A specialized enumerator may reduce solver calls, but cannot avoid representing all K values when exact uniform support is required. | Exact projected support, empty/over-cap behavior, coupling cases, and distribution equivalence against the current implementation. | Check/model/blocker counts, support size, fallback rate, and per-randomize time. No algorithm change based solely on synthetic solver-call counts. |
| 3 | **SRAM name lookup:** repeated `find_name` scope scan O(M) → cached successful `(scope,name)` lookup, average O(1); a per-scope index costs O(M) to build plus average O(1) per name. | Same resolved handles and values for indexed arrays, ranges, escaped names, packed selections, and misses; test cache lifetime. | Cache hit/miss, `find_name`, `get_word_str`, fallback counts, and SRAM phase time. Promote only if scans fall and the same-input phase improves. |
| 4 | **RV-DM joint tuples:** current enumeration makes O(T) solver/model iterations for T legal tuples. Component factoring could avoid materializing a Cartesian product only for proven independent components with equivalent weighting. | Exact complete tuple set and order, including coupled inputs, weights, auxiliary variables, and cap behavior. | Solver/model/blocker counts, tuple count, peak memory, and focused randomization time. Compare independent and coupled fixtures. |
| 5 | **SVA callback dispatch:** preserve O(1) table lookup while removing repeated VPI iterator/value/scope work for stable call sites. | Existing assertion enable/disable, selective-label, automatic-scope, and multiclock kill/restart results. | VPI operations and time per callback; promote only if operations fall and callback-heavy fixture time improves. |
| 6 | **Object/context bookkeeping:** owner+live checks use two hash lookups; a combined record may reduce them to one. Alias notification still has a lower bound proportional to fanout. | Same live-context decisions, notification fanout, callback-time subscription mutation, teardown, and pointer reuse/generation. | Hash probes, fanout, copied bytes, and update time. Do not add hashing to registries that already use hash containers. |
| 7 | **Four-state conversion:** reduce per-bit overhead while retaining O(W) work for W bits. | Exhaustive equivalence over four/eight-state and drive-strength inputs against the current resolver. | Converted bits/second, `set_bit`/`reduce4` counts, and wide-bus fixture time. |
| 8 | **Virtual-interface lookup:** repeated P×M scan (P properties, M scope entries) → O(M) scope index build plus average O(P) lookups, or reduce RTTI by matching names first. | Same slot handle and kind for signal, array, real, string, object, and absent property. | Scope entries scanned, RTTI calls, constructions/second, and setup time. |
| 9 | **Standard distribution:** reuse branch metadata or sample direct only for fixed supports; no complexity gain is established for the coupled general case. | Exhaustively compare feasible values and exact weights for small domains, including `:=`/`:/`, signed sizing, clipping, and coupled constraints. | Branch builds, solver checks, allocations, fallbacks, and calls/second. Histograms alone are not a correctness oracle. |

For a proposed change, first run the bounded fixture five times on the same
host/build and report the median plus spread for the directly targeted metric
and an end-to-end focused case. A proposed screening threshold is at least 10%
median improvement beyond observed run-to-run noise, with no more than 2%
regression in the neighboring control case; these are roadmap gates, not
measured results or language requirements. If baseline spread exceeds 5%,
improve the measurement before judging the candidate. Passing the semantic
oracle is required regardless of timing. The existing C++ draft specifies
logarithmic ordered `upper_bound` and average O(1), worst-case linear unordered
lookup; these bounds support the AA tree and name-cache designs, respectively,
but do not guarantee workload speedups ([ordered containers](https://eel.is/c++draft/associative.reqmts),
[unordered containers](https://eel.is/c++draft/unord.req.general)).

The research sources are method references, not measurements of these
OpenTitan paths: [Pugh's ordered skip list](https://doi.org/10.1145/78973.78977),
[All-SMT enumeration](https://doi.org/10.1109/ARES.2015.14), and the later
[projected SAT/SMT enumeration study](https://doi.org/10.1016/j.artint.2025.104346).
The [IEEE 1800-2023 standard](https://standards.ieee.org/ieee/1800/7743/)
defines the SystemVerilog semantic contract; the
[OpenTitan backdoor utility docs](https://opentitan.org/book/hw/dv/sv/mem_bkdr_util/index.html)
describe its supported read widths. No primary academic performance result was
found for the VPI callback, alias/liveness, four-state conversion, or VIF slot
paths themselves; their case for optimization is the local profile plus a
future focused before/after measurement.

## Implementation order

This order reflects likely corpus benefit from the post-index census, not
algorithm novelty. Flash remains the longest row (5,756 seconds in census14)
and its later phase still samples `uvm_hdl_read` and VPI name lookup. Sparse Z3
appears across several other long rows, so instrument it before selecting an
enumeration algorithm. The bounded fixtures identify candidate costs but do
not yet show a speedup for any remaining path.

1. **Complete:** implement and verify the Flash semantic ordered index. It is
   covered by a full-size bounded comparison and isolated Flash replay.
2. Measure Flash word-read batching with VPI-call counters. Keep OpenTitan
   utility changes opt-in until ECC and subclass behavior are proven.
3. Add targeted counters to sparse and joint Z3 paths. Use the fixtures to
   distinguish solver work from support-set size before changing algorithms;
   the shared sparse path has higher cross-corpus reach than SRAM lookup.
4. Measure SRAM base-handle caching with VPI-call counters and the UVM wrapper
   in the loop. The current direct-VPI fixture does not establish a UVM-path
   speedup.
5. Address callback/object bookkeeping and four-state conversion with
   behavior-focused regressions; optimize only measured operations.
6. Optimize virtual-interface setup and standard distributions after sustained
   runtime paths. A seeded histogram alone does not prove distribution
   correctness.

VVP interprets .vvp output; ahead-of-time native compilation of OpenTitan SV
is not the available route. Practical targets are measured C++ VVP/VPI/Z3
paths and reducible backdoor work.
