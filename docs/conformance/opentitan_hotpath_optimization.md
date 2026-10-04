# OpenTitan hot-path optimization plan

Source-backed profile and census evidence is in
[HOTPATHS.md](../../evidence/opentitan-census-20261002/census12-full-corpus-20261003/HOTPATHS.md).
Bounded reproducers and measurements are in
[benchmarks/opentitan-hotpaths](../../benchmarks/opentitan-hotpaths/README.md).
Profiles are phase snapshots with overlapping inclusive counts, not whole-run
CPU percentages.

## Prioritized plan

| Path | First speedup step | Risks and minimum validation |
| --- | --- | --- |
| **Flash associative-array next** | Replace repeated full-map scans with a semantic ordered index. upper_bound per call changes a full walk from O(N²) to O(N log N). The 262,148-key fixture took 84 ms for repeated tree queries; the iterator best case took 1 ms. Hash plus ordered index was slower here. | Keep signed/unsigned ordering, sign extension, four-state order, and raw-width identity. Confirm signedness is fixed per array before maintaining one index, or index both modes. Update indexes on every insert/delete and query the live index so mutations are visible. Validate signedness, mixed widths, 0/1/X/Z, absent keys, duplicate numeric values with distinct widths, mutation, and copy/clear. The C++ standard guarantees logarithmic lookup for ordered associative containers; Pugh's skip list is a studied alternative, but neither source proves this runtime's gain: [ordered-container requirements](https://eel.is/c++draft/associative.reqmts), [Pugh, Skip Lists](https://doi.org/10.1145/78973.78977). |
| **Flash backdoor population** | Add an opt-in packed-word read for the Flash layout, reducing up to four byte-level HDL reads per read32 to one. | Check alignment, byte order, data/ECC mapping, X/unknown behavior, and virtual overrides. Compare packed reads to the current four-read reference at boundaries; measure VPI calls and model-build time. [OpenTitan memory backdoor docs](https://opentitan.org/book/hw/dv/sv/mem_bkdr_util/index.html). |
| **Sparse-wide Z3 enumeration** | Instrument solver checks, model extraction, blockers, support size, cap fallback, and time per randomize. Specialize only provable small finite sets or bounded intervals. | Preserve exact feasible support and distribution semantics; approximate model sampling is not equivalent. Compare feasible sets, seeded behavior, and weights for sparse, coupled, and over-cap cases. All-SMT work explores alternatives to blocking-clause enumeration, but is not a drop-in SV sampler: [Phan et al.](https://doi.org/10.1109/ARES.2015.14), [Spallitta et al.](https://arxiv.org/abs/2410.18707). |
| **RV-DM joint Z3 tuples** | Measure separately from sparse domains. Factor disconnected variable components only after proving independence; this may avoid enumerating a Cartesian product. | Preserve tuple support, multiplicity/weights, sort order, cap behavior, and exclude auxiliary variables. Compare exact tuples and frequencies on independent and coupled models. General All-SMT work does not establish SV randomization equivalence here. |
| **SRAM indexed VPI lookup** | Cache the resolved array base by scope and name; if profiles show broad scans, consider a per-scope name index. The current indexed path still resolves the base through find_name. | Track cache lifetime and escaped-name handling. Compare handles and values for indexed arrays, ranges, packed selections, escaped identifiers, and missing names; count find_name, get_word_str, and fallback calls. |
| **SVA/VPI dispatch** | Reduce wrapper work around the existing (scope,index) hash. Resolve stable call-site IDs/handles once or lower them to a direct runtime operand where valid. | Preserve automatic-scope identity, handle lifetime, and multiclock $assertkill generations. Count iterator/get/scope lookups per callback; run assertion-control stress, selective labels, and multiclock kill/restart cases. Use the [IEEE 1800 VPI contract](https://standards.ieee.org/ieee/1800/7743/) as the semantic authority. |
| **Object/context/liveness** | Count probes first. If owner and live-state checks dominate, combine them into one context record. If notifications greatly outnumber subscriptions, consider immutable copy-on-write alias snapshots. | Preserve callback-time registration changes, teardown, pointer reuse/generation, and destruction order. Test reentrant subscribe/unsubscribe and automatic-context teardown/reuse; measure fanout and copied bytes. Registries already use hash containers, so hashing alone is not an optimization plan. |
| **Four-state conversion/resolution** | Try packed conversion or a small lookup table to reduce per-bit conversion and setter calls. This is a constant-factor change, not a complexity change. | Exhaustively compare four/eight-state and drive-strength combinations against the existing resolver, then measure wide buses. Preserve X/Z and strength behavior. |
| **Virtual-interface slot resolution** | First compare member names before RTTI checks. If repeated construction still dominates, build a per-scope name/type index once. | Check signals, arrays, reals, strings, objects, and missing properties. Count scope entries and RTTI calls across repeated construction; this is startup-only and ranks below sustained paths. |
| **Standard distribution randomization** | Instrument branch construction, solver checks, allocations, and fallback. Reuse immutable normalized branch metadata; consider direct exact weighted sampling only for proven fixed supports. | Preserve := versus :/, signed sizing/clipping, constraint coupling, and random-stream use. Exhaustively compare small-domain support and weights before timing. Alias sampling is a researched discrete method, but its applicability and exact integer-weight behavior must be established: [INFORMS alias-method analysis](https://doi.org/10.1287/ijoc.1030.0063). |

## Implementation order

1. Implement and verify the Flash semantic ordered index. It is the clearest
   asymptotic issue and has a full-size bounded comparison.
2. Measure Flash word-read batching and SRAM base-handle caching with VPI-call
   counters. Keep OpenTitan utility changes opt-in until ECC and subclass
   behavior are proven.
3. Add targeted counters to sparse and joint Z3 paths. Use the fixtures to
   distinguish solver work from support-set size before changing algorithms.
4. Address callback/object bookkeeping and four-state conversion with
   behavior-focused regressions; optimize only measured operations.
5. Optimize virtual-interface setup and standard distributions after sustained
   runtime paths. A seeded histogram alone does not prove distribution
   correctness.

VVP interprets .vvp output; ahead-of-time native compilation of OpenTitan SV
is not the available route. Practical targets are measured C++ VVP/VPI/Z3
paths and reducible backdoor work.
