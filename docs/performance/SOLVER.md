# Randomization solver tiers

The M3 WP7 prototype and measurements below are pinned to source base
`8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1` (`origin/main` when that work
started). The M5 WP7-T1 screen uses its own pinned base and is reported in a
separate section. The initial T1 candidate passed full-corpus and Caliptra
checks; the cached-hull follow-up is awaiting its full gates. A tier is
selected for each effective class constraint set. If the runtime cannot prove
that a cheaper tier is exact, it falls through to the next tier. Seeded values
and legal-value distributions are release gates.
Changing either requires an explicit user decision; it is a hard stop for this
WP until then.

## Proposed tier order

| Tier | Exact path | Conservative fallback |
| --- | --- | --- |
| T0 | No active constraints: reuse the values already selected during randomize prefill (including existing `randc`, enum, and container behavior) and skip Z3. | T1 if extra, inherited, or inline constraint IR remains. |
| T1 | Independent single-variable ranges, `inside`, constant `dist`, and enum domains; sample natively with the existing per-object RNG. | T2 if any constraint couples variables or has state-dependent terms. |
| T2 | Small supported relations over a few variables, such as linear or bit relations and implication with constant guards; propagate only when the complete legal set and required distribution are proven. | T3 on unsupported operators, state reads, arrays, or uncertainty. |
| T3 | Ordinary hard constraints through a per-class incremental Z3 session with push/pop or assumptions. | T4 for optimization or dynamic/array semantics. |
| T4 | Full solver semantics for soft constraints, `solve before`, `unique`, `foreach`, arrays, and dynamic constraints. | Fail the randomize call if the full solver cannot establish a result. |

T1 and T2 must preserve the exact sampling contract before they can replace the
current solver. A path that merely returns legal values is not enough. A
bounded search or rejection loop is not an exact T2 path unless it proves
termination and preserves the required distribution. T3 session reuse also
remains gated on seeded-value identity because solver history can influence
model selection; a previous one-context-across-calls experiment was rejected
for this reason (see the sim-hotspots attempt ledger).

A general tier classifier should be cached by the effective constraint set,
not just the class name: class identity and inherited owners,
enabled-constraint and rand-mode bitmaps, and the inline-constraint AST/call
site. Dynamic container shape belongs in the key when it changes the
constraint structure. State values that only parameterize a proven static
shape are inputs to a call, not reasons to re-parse the IR.
`constraint_mode()` changes select another cached entry; copies carry their
mode bitmaps but must not share mutable solver sessions. The M3 prototype below
used an O(1) T0 active-constraint count. M5 T1 caches only its proven scalar
class/mode plans and falls back for inline or other unsupported inputs.

## M3 T0 implementation and measurements

At the M3 measurement point, the prototype implemented T0 for classes whose
entire effective constraint set was disabled. `randomize_cobject_` had already
prefilled the active random properties; with no extra IR, this was equivalent
to the existing zero-constraint early return. A per-object active-constraint count is
kept in step with `constraint_mode()` changes and copies. This avoids creating
a Z3 context for that case. The existing no-declared-constraint path already
returns before Z3, so it is not a new speedup. T1 and T2 were not implemented in that M3 measurement; ordinary constrained
calls used a fresh Z3 context, and the requested per-class incremental context
cache remained unimplemented.

For that M3 build, the opt-in `IVL_PERF_STATS=1` report counted T0 returns and
classified the remaining fresh-Z3 calls into ordinary hard-constraint
(T3-eligible) and full-solver (T4) buckets. T3 here means eligible for the proposed
incremental Z3 session; those calls still create a new context each time. The
classifier runs per call and is not cached by constraint set. T1 and T2 are
zero because neither native path is implemented. T0 includes the existing
no-declared-constraint fast return as well as the new all-disabled-constraints
path.

### Calls observed per tier

| Workload | T0 / T1 / T2 / T3-eligible / T4 calls | Z3 contexts |
| --- | ---: | ---: |
| `randomize_z3` (400 draws per class) | 0 / 0 / 0 / 800 / 0 | 800 |
| `randomize_dv_txn` (400 draws) | 0 / 0 / 0 / 0 / 400 | 400 |
| UVM `uvm_traffic` sequence (5,000 items) | 5,000 / 0 / 0 / 0 / 0 | 0 |
| Caliptra `smoke_test_dma_aes_gcm_short_1_dword` | 0 / 0 / 0 / 0 / 0 | 0 |
| Caliptra `smoke_test_sha256` | 0 / 0 / 0 / 0 / 0 | 0 |
| Caliptra `cptra_ss_test_rom` | 0 / 0 / 0 / 0 / 0 | 0 |
| T0 disabled-constraint fixture (400 calls) | 400 / 0 / 0 / 0 / 0 | 0 |
| T4 soft-only fixture (400 calls) | 0 / 0 / 0 / 0 / 400 | 400 |

The UVM sequence's 5,000 T0 calls were already handled by main's no-declared-
constraint return. None of the three Caliptra windows called `randomize()`.
`randomize_z3` stayed on the ordinary hard-constraint Z3 path. The transaction
workload uses a constant `dist`; until an exact native sampler exists, it
falls back to the full Z3 path to preserve the weighted distribution. The
corrected opt-in histogram from Slurm job 3394 is preserved at
[`histogram.json`](../../evidence/wp7-tiered-rand-8c95-20261020/attempts/tier-classifier-fix-recheck-20261020/results/histogram.json); it
supersedes the earlier T3 label for `randomize_dv_txn` without changing the
stats-off measurements.

### Callgrind speedup and seeded-value identity

All measurements below use the same pinned reference and candidate base. The
ratio is reference instructions divided by candidate instructions. The 18-row
corpus completed with byte-identical outputs after one isolated retry of the
`waveform_fst` Callgrind run; the first candidate attempt exited 139, while the
plain run and retry passed for both builds. The largest other-workload increase
was `classq` at 0.001328%, below the 2% regression ceiling.

| Tier and workload | Reference instructions | Candidate instructions | Speedup | Seeded output |
| --- | ---: | ---: | ---: | --- |
| T0, disabled constraints (400 calls) | 1,897,719,601 | 25,462,724 | 74.5293x | byte-identical |
| T1 | not implemented | not measured | n/a | unchanged; no T1 path |
| T2 | not implemented | not measured | n/a | unchanged; no T2 path |
| Fresh Z3, T3-eligible: `randomize_z3` (800 calls) | 13,024,383,760 | 13,024,382,258 | 1.0000001x | byte-identical |
| Fresh Z3, T4 distribution fallback: `randomize_dv_txn` (400 calls) | 42,298,006,676 | 42,298,005,881 | 1.00000002x | byte-identical |
| T0 existing return, `uvm_traffic` (5,000 calls) | 40,374,257,609 | 40,374,320,247 | 0.9999984x | byte-identical; path already existed on main |
| T4, soft-only (400 calls) | 3,208,441,785 | 3,208,441,124 | 1.0000002x | byte-identical |

The disabled-constraint fixture's seeded output SHA-256 is
`43c33e3238b9cd7adc626e0f899a0289a9f30708fcc0cc34ec45cf8811ba7914f` on both
builds. The soft-only fixture's output SHA-256 is
`360f2bc1511a8440d1c28d1eb53ce364b0f12c06516ef07a5bc865fe611edd13` on both.
T3/T4 retain the existing Z3 implementation and match byte-for-byte. T1/T2
have no implementation or changed values.

### Caliptra throughput check

Each build ran once per test over the fixed `mcycle` window 100–2,100. This is
supporting evidence only: one sample gives no spread estimate, and the tier
counters show that these windows made no randomization calls.

| Test | Pinned main cycles/s | Candidate cycles/s | Candidate/main |
| --- | ---: | ---: | ---: |
| `smoke_test_dma_aes_gcm_short_1_dword` | 10.970354 | 10.852329 | 0.989241x |
| `smoke_test_sha256` | 10.670085 | 10.876127 | 1.019310x |
| `cptra_ss_test_rom` | 9.892345 | 10.116338 | 1.022643x |
| Three-test geometric mean | - | - | 1.010286x |

Firmware images and normalized logs matched for all three tests. This T0 change
does not improve the measured Caliptra tests; its measured target is the
disabled-constraint case. Evidence and raw profiles are in
[`evidence/wp7-tiered-rand-8c95-20261020/`](../../evidence/wp7-tiered-rand-8c95-20261020/).

The Z3 context attempt ledger measures context creation at about 2.7 ms per
constrained `randomize()` (12.7% of `randomize_dv_txn` CPU time). Reusing one
context across calls was rejected because model-ordered sampling can change
values based on unrelated earlier randomizations. This prototype does not
reuse contexts. T1/T2 sampling and a cache keyed by the effective constraint
set remain future work and require exact legal-set, distribution, and seeded
stream checks before they can be considered for release.

## M5 WP7 T1 screen (base `10f3a0a2509d0852c2556cb6622fb0025121fb2d`)

The T1 candidate caches plans by class identity plus constraint-mode and
rand-mode bits. Eligibility is deliberately narrow: one object, one scalar rand
property of at most 10 bits, not randc or static, with no inheritance, inline
or external constraint IR, dynamic shape, class-state inputs, soft constraints,
ordering, or uncertain four-state value. For unweighted range and enum constraints, it returns only
when the existing prefill is already in the cached legal domain; otherwise it
uses the existing solver. For constant-weight `dist`, it reuses the exact
resolver plan and per-object RNG stream. Unrecognized shapes continue through
the current solver. This adds no dependency and changes no seeded values in the
focused checks.

Slurm job 3652 recorded T1 hits on range 35/64, enum 40/64, and overlapping
constant `dist` 63/64 (the first call builds the cached plan). The five seeded
fixtures/traces matched their pinned reference byte-for-byte; `randomize_z3`
remained T3 for 800 calls, and `randomize_dv_txn` remained T4 for 1,000 calls.
Job 3657's focused Callgrind pass reports:

| Fixture | Reference instructions | Candidate instructions | Speedup | Seeded output |
| --- | ---: | ---: | ---: | --- |
| Scalar range (64 draws) | 597,636,464 | 392,317,448 | 1.523x | byte-identical |
| Enum (64 draws) | 634,042,112 | 395,321,007 | 1.604x | byte-identical |
| Overlapping constant `dist` (64 draws) | 759,033,511 | 20,493,962 | 37.037x | byte-identical |

The seven focused output pairs, including `randomize_z3` and `randomize_dv_txn`
controls, have matching hashes. The final frozen candidate's eight-seed traces
are summarized in the [validation record](../../evidence/wp7-t1-10f3a0a-20261021/validation/README.md).

Job 3657 completed the pinned 18-workload Callgrind screen. All outputs matched
byte-for-byte, and no non-target workload regressed by more than 2%:

| Workload | Reference instructions | Candidate instructions | Speedup | Candidate delta |
| --- | ---: | ---: | ---: | ---: |
| `randomize_z3` | 13,042,027,825 | 13,042,567,950 | 0.999959x | +0.004141% |
| `randomize_dv_txn` | 42,384,354,655 | 42,383,568,174 | 1.000019x | -0.001856% |

The candidate tier histogram shows why T1 does not move those benchmarks:

| Workload | Calls by tier (T0 / T1 / T2 / T3 / T4) | Z3 contexts |
| --- | --- | ---: |
| `randomize_z3` | 0 / 0 / 0 / 800 / 0 | 800 |
| `randomize_dv_txn` | 0 / 0 / 0 / 0 / 400 | 400 |
| `uvm_traffic` | 5,000 / 0 / 0 / 0 / 0 | 0 |
| Unconstrained control | 400 / 0 / 0 / 0 / 0 | 0 |
| Soft-constraint control | 0 / 0 / 0 / 0 / 400 | 400 |

The earlier UVM control mismatch was a harness artifact: separate reference and
candidate compiles embedded different absolute source roots. Job 3657's corpus
runner compiles each UVM program once and runs the same bytecode on both
runtimes; its UVM outputs match byte-for-byte.

Caliptra UVM histogram:

| Caliptra test | Reference T0 / T1 / T2 / T3 / T4 | Candidate T0 / T1 / T2 / T3 / T4 |
| --- | --- | --- |
| `smoke_test_dma_aes_gcm_short_1_dword` | 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 |
| `smoke_test_sha256` | 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 |
| `cptra_ss_test_rom` | 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 |

Job 3681 ran all six 2,000-mcycle windows on the unchanged job 3657 binaries.
Its in-job comparator exited 1 on a wall-clock progress heartbeat whose mcycle
value differed between builds. An offline analyzer normalized that timing-only
heartbeat, the perf-stat record, the elapsed-time
field, and the known reference/candidate source-root prefixes; all three
functional logs and firmware-hex hashes then matched. Raw logs remain preserved.
No Caliptra test called `randomize()`, so T1 has no Caliptra speedup opportunity.

A follow-up tried caching the isolated interval domain for the wide `addr`
factor in `randomize_dv_txn`, with the factor expression included in the cache
key and bounded negative caching for domains that could not be represented
compactly. Its shared-bytecode 400-call trace remained byte-identical, but
Callgrind instructions rose from 42,398,397,920 to 46,128,357,195 (+8.797406%,
0.919140x). The extension exceeded the 2% regression limit and was removed.
The call-level histogram still classifies `randomize_dv_txn` as T4; a faster
single-property probe does not qualify the whole call as T1 while Z3 remains
necessary. The rejected interval-cache variant is not in the candidate.

T1 fixture speedups remain narrow examples, not headline wins. No seeded value
or tested distribution changed. Continue with T2/T3 on the same pinned base.

## M5 WP7 T2 small-domain proposal replay

The first T2 screen caches complete legal tuples for a narrow class shape:
single-object, two-state direct scalar variables, at most four variables and
16 total input bits, no soft/dist/solve-before or dynamic state, and at most 64
legal tuples. The fast path replays the current solver's first 64 full-domain
proposals with the same object RNG. If they miss, it rewinds the RNG tape and
falls through, leaving the existing projection and exact-sampling path intact.
This lets the common successful proposal skip context creation without
changing the selected tuple.

Slurm job 3715 measured the `small_dom` component in `randomize_z3`: T2 handled
282 of 800 calls and all per-draw outputs matched the pinned reference. Its
Callgrind total fell from 13,009,165,472 to 8,063,619,990 instructions
(1.613316x). `randomize_dv_txn` remained T4 and byte-identical at
106,040,608,074 versus 106,040,889,211 instructions (0.999997x, +0.000265%).
The job script's post-check expected 400 transaction calls while the benchmark
ran its default 1,000; the post-run analyzer used the correct count and
validated both profiles and traces. The r1 source patch predates the inherited/invalid-graph guard. Full-corpus
job 3731 remains queued on the pinned base with guarded T2 patch SHA-256
`1683a2c31fc58aa5dde3a019bf574b2de63d43fbd8e1330fda23170968aad537` (4 CPUs,
4 GiB). Focused job 3735 completed the later guarded-zero patch
(`b4973dd35a3b337586c1ac68338cdc6e2158ddc342e396c8492e5270fa2f4726`) with
exit code 0. Its per-draw traces match. T2 handles 282/800 calls in
`randomize_z3`; `randomize_dv_txn` remains T4 for 1,000 calls. This focused run
does not validate the full corpus or correctness gates:

| Workload | Reference instructions | Candidate instructions | Speedup | Candidate delta | Seeded output |
| --- | ---: | ---: | ---: | ---: | --- |
| `randomize_z3` | 13,029,275,482 | 8,075,586,539 | 1.613415x | -38.019681% | byte-identical |
| `randomize_dv_txn` | 106,012,296,160 | 106,012,838,105 | 0.999995x | +0.000511% | byte-identical |

A bounded T3 context and simple-solver session keeps one cached solver per eligible class context. Each call asserts under an outer push and pops on exit; nested calls use a temporary solver. Its cumulative T1/T2/T3 patch is SHA-256
`5c84594647c78682a940e861f7af08965c11ff4efc8c80af64660ed7800b7a12`. Slurm
job 3742 completed its focused screen. The default-seed traces matched, and
context creations fell from 800 to 33 for `randomize_z3` and 1,000 to 63 for
`randomize_dv_txn`:

| Workload | Reference instructions | Candidate instructions | Speedup | Candidate delta |
| --- | ---: | ---: | ---: | ---: |
| `randomize_z3` | 13,041,261,451 | 5,787,306,872 | 2.253425x | -55.623105% |
| `randomize_dv_txn` | 105,926,369,305 | 99,569,594,301 | 1.063843x | -6.001126% |

The transaction target missed the 10% advancement gate; candidate peak RSS was
42,352 KiB versus 41,016 KiB for the reference. A follow-up T3 cache for exact
isolated-factor analysis was measured in Slurm job 3752, on the same pinned
base and with the same tier stack. Its patch SHA-256 was
`fa1107260bff60b32cd3b73ebd45d78ac91b7b66aec1231e2c2b7285ac7fe28c`.
Default-seed outputs and traces matched byte-for-byte, and context creations
fell from 800 to 33 and 1,000 to 63. Callgrind totals were:

| Workload | Reference instructions | Candidate instructions | Speedup | Candidate delta | Candidate tier histogram |
| --- | ---: | ---: | ---: | ---: | --- |
| `randomize_z3` | 13,041,301,157 | 5,786,768,181 | 2.253642x | -55.627371% | 282 T2 / 518 T3 |
| `randomize_dv_txn` | 105,926,426,461 | 99,586,113,217 | 1.063667x | -5.985582% | 1,000 T4 |

The extra factor cache made no material difference to job 3742 and did not
meet the 10% per-target screen. Peak RSS was 41,028 vs 40,952 KiB for
`randomize_z3` and 42,708 vs 41,188 KiB for `randomize_dv_txn` (reference vs
candidate); the latter is +3.69%. The 18-workload corpus and multi-seed sweep
were not run because the candidate failed advancement. Reject and remove this
cache before the next experiment.
The cumulative T1/T2/T3 stack remains below the M5 10x target. T1 job 3759
tried a positive-only isolated-count cache keyed by all active assertion AST
IDs. Default-seed outputs matched, but it recorded zero cache hits in either
target. Callgrind remained at 2.255187x for `randomize_z3` and 1.063459x for
`randomize_dv_txn`, so the full-assertion key is rejected. The next T1 variant
keys the proven result by the exact isolated factor AST, subject, width, and
cap after computing that factor. Slurm job 3763 passed the focused screen:
874/1,000 DVT calls hit the cache, all default-seed output pairs matched, and
Callgrind improved `randomize_z3` 2.254952x and `randomize_dv_txn` 1.453790x.
Peak transaction RSS rose 2.88% in the focused run. At that stage, multi-seed,
full-corpus, and full correctness gates remained pending; all were completed
for the frozen candidate in the final validation section below. False and
unknown counts retain the existing exact path. The final validation record has
the complete candidate results.

## Bitwuzla spike

The local-only spike used Bitwuzla `0.9.1-dev-main@90de49c` and Z3 `5.1.0.0` on
macOS ARM64. It ported the hard bit-vector constraints from `table18_2_unordered`,
`small_dom`, and `randomize_dv_txn`. The DV transaction's `dist` weights were
intentionally omitted from the hard-constraint SMT-LIB input. The incremental
test ran 1,000 push/check/model/pop iterations per process, with nine
interleaved processes per solver and workload:

| Hard constraint set | Z3 median / RSS | Bitwuzla median / RSS | Bitwuzla speedup |
| --- | ---: | ---: | ---: |
| `table18_2_unordered` | 173.2 ms / 22.8 MiB | 41.6 ms / 5.5 MiB | 4.16x |
| `small_dom` | 169.6 ms / 22.8 MiB | 83.6 ms / 6.7 MiB | 2.03x |
| DV transaction, hard clauses only | 197.8 ms / 22.8 MiB | 88.4 ms / 7.3 MiB | 2.24x |

These are solver API microbenchmarks, not end-to-end `randomize()` timings:
they omit Icarus constraint parsing, SV sampling/distribution, hooks, object
RNG state, and simulator overhead. Separate fresh-process checks were close to
process startup time and are not used to support the speedup claim. Bitwuzla's
public API supports incremental push/pop and check-sat-assuming; Z3 additionally
provides weighted soft assertions and optimization objectives ([Bitwuzla C
API](https://bitwuzla.github.io/docs/c/api.html), [Bitwuzla incremental solver
API](https://bitwuzla.github.io/docs/c/types/bitwuzla.html), [Z3 Optimize
API](https://z3prover.github.io/api/html/classz3_1_1optimize.html)).

### Semantic gaps

- **Soft constraints (IEEE 1800 18.5.14):** Bitwuzla has no MaxSMT/soft-objective
  API. A host could introduce Boolean selectors and solve under assumptions,
  then iteratively relax lower-priority groups. That requires implementing and
  validating the standard's priority, override, and conditional-soft rules;
  the spike did not prove this mapping equivalent. Z3 already exposes weighted
  soft assertions.
- **`dist`:** Bitwuzla can decide hard feasibility, but the host must perform
  exact weighted sampling, including overlapping ranges and the distinct
  `:=` versus `:/` meanings. The DV transaction port excluded its weights, so
  its result says nothing about distribution compatibility.
- **`solve before`:** A replacement must preserve the required variable-order
  distributions, not merely find a satisfying model. Assumption-based
  relaxation could make a prototype, but the required marginal sampling and
  interaction with `dist` remain unimplemented.

Bitwuzla is promising for hard QF_BV feasibility and memory use, but it is not a
drop-in replacement for the current IEEE feature set. Recommendation: keep Z3
as the full-semantics backend, implement exact native T0/T1/T2 fast paths first,
and revisit a Bitwuzla backend only if later end-to-end measurements justify
the semantic adapter. Bitwuzla is MIT licensed ([COPYING](https://github.com/bitwuzla/bitwuzla/blob/main/COPYING));
this spike built it under `/tmp` and adds no project dependency.

## M5 validation of the frozen cumulative candidate

All measurements below use base
`10f3a0a2509d0852c2556cb6622fb0025121fb2d` and candidate patch SHA-256
`d732f301ae0abcb05dd5a3093d40f9ae40460fa0e104572a414892afcfef5db0`.
Correctness job 3769 passed `make check`, FPGA target install, 15 runtime
invariants, the full JSON suite (4,804/4,804), and real-DPI UVM (367 passed,
zero failed or skipped).

The eight-seed replay matched byte-for-byte for scalar range, enum, constant
`dist`, `randomize_z3`, and `randomize_dv_txn`. All 18 corpus workloads also
matched. Job 3768's first FST reference run exited 139 under Callgrind. Recovery
job 3798 produced two complete reference/candidate pairs with identical FST
outputs; later reference attempts intermittently segfaulted inside Valgrind's
worker thread. Those failed partial profiles were excluded. The 18-row table
uses the 17 completed job-3768 rows and the median counts from the two clean FST
pairs; their instruction counts were stable to less than 0.001%.

| Workload | Reference instructions | Candidate instructions | Speedup | Candidate tier |
| --- | ---: | ---: | ---: | --- |
| T1 scalar range (64 draws) | 597,973,999 | 259,882,774 | 2.300937x | 35 T1 / 29 T3 |
| T1 enum (64 draws) | 633,193,352 | 288,229,331 | 2.196839x | 40 T1 / 24 T3 |
| T1 overlapping constant `dist` (64 draws) | 759,682,445 | 20,452,875 | 37.143064x | 63 T1 / 1 T4 |
| `randomize_z3` (800 draws) | 13,029,743,540 | 5,782,293,390 | 2.253387x | 282 T2 / 518 T3 |
| `randomize_dv_txn` (400 draws) | 42,392,887,693 | 29,154,097,702 | 1.454097x | 400 T4; 350 isolated-count cache hits |
| UVM `uvm_traffic` sequence (5,000 items) | — | — | — | 5,000 T0 in both builds |

No other corpus workload regressed by more than 2%; the largest increase was
`classq` at +0.026751%. In the cumulative candidate, `randomize_z3` context
creations fell from 800 to 33. The 400-call `randomize_dv_txn` run fell from
400 contexts to 25.

All three Caliptra top-level cases recorded zero randomize calls in both builds.
The fixed 100–2,100 mcycle windows had byte-identical functional logs after
removing only perf-stat records, elapsed-time fields, progress-heartbeat lines,
and the two known source-root prefixes; generated firmware hashes were
identical. This is evidence that the candidate does not affect those Caliptra
tests, not a Caliptra speedup.

The M5 10x target remains unmet. The measured improvements exceed the per-WP
10% instruction gate on both named workloads, but do not qualify M5 as
complete. No seeded value or tested distribution changed, and no dependency
was added. Reviewable traces and machine-readable Callgrind and tier summaries
are in the [validation record](../../evidence/wp7-t1-10f3a0a-20261021/validation/README.md).
Generated Caliptra build trees remain in the local artifact copy and are not
included in the PR.

### T1 cached-hull follow-up

The exact-interval cache attempt had zero hits over 1,000 DVT randomizations:
the normal hull rejection usually succeeds before the sampler discovers a full
interval union. A narrower per-context cache stores only the proven min/max
hull and the count of boundary queries used to prove it. Cache hits skip those
same queries, then preserve the 64 full-domain proposals, hull proposals, and
later query cap. The key uses the subject and isolated-factor AST IDs, so a
changed effective factor cannot reuse an old hull.

Slurm job 3818 compared the pinned base, PR #933, and this candidate. Default
outputs and eight seeded outputs matched byte-for-byte. The 1,000-call DVT run
recorded 874 hull-cache hits and reduced Z3 checks from 93,340 to 37,404.
Callgrind results were:

| Workload | Pinned base | PR #933 | Candidate | Candidate vs PR #933 |
| --- | ---: | ---: | ---: | ---: |
| `randomize_dv_txn` | 106,077,741,143 | 72,981,246,600 | 44,754,551,050 | 1.630700x (-38.68%) |
| `randomize_z3` | 13,023,158,864 | 5,781,316,490 | 5,782,607,074 | 0.999777x (+0.0223%) |

This passes the focused 10% target and 2% regression screen. It leaves the
whole-call tiers unchanged (`randomize_dv_txn` T4; `randomize_z3` 282 T2 / 518
T3). The cumulative speedups over the pinned base are 2.370211x and 2.252126x,
so the M5 10x goal remains unmet. Multi-seed and full-corpus correctness gates
for this candidate are pending. The exact output hashes, profile hashes, and
runner details are in
[`evidence/wp7-t1-10f3a0a-20261021/attempts/t1-hull-cache/`](../../evidence/wp7-t1-10f3a0a-20261021/attempts/t1-hull-cache/).
The measured hull patch SHA-256 is
`e3b7376125b75518391e010e26a48bd094577d5cfbb67f4556906f1d37f3de76`; the
submitted patch adds only the explanatory query-cap comment (SHA-256
`690decbc7ac17487666faa250dc8514a587b062f6abf96c8a4f7bcfe0079bc10`).
