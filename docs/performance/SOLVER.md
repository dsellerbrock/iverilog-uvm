# Randomization solver tiers

WP7 experiments are pinned to source base
`8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1` (`origin/main` when this work
started). A tier is selected for each effective class constraint set. If the
runtime cannot prove that a cheaper tier is exact, it falls through to the
next tier. Seeded values and legal-value distributions are release gates.
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

Classification should be cached by the effective constraint set, not just the
class name: class identity and inherited owners, enabled-constraint and
rand-mode bitmaps, and the inline-constraint AST/call site. Dynamic container
shape belongs in the key when it changes the constraint structure. State
values that only parameterize a proven static shape are inputs to a call, not
reasons to re-parse the IR. `constraint_mode()` changes select another cached
entry; copies carry their mode bitmaps but must not share mutable solver
sessions. The prototype does not yet have this cache: T0 uses an O(1) active
constraint count, while tier counters classify each call for measurement.

## Current implementation and measurements

The current prototype implements T0 for classes whose entire effective
constraint set is disabled. `randomize_cobject_` has already prefilled the
active random properties; when there is no extra IR, this is equivalent to the
existing zero-constraint early return. A per-object active-constraint count is
kept in step with `constraint_mode()` changes and copies. This avoids creating
a Z3 context for that case. The existing no-declared-constraint path already
returns before Z3, so it is not a new speedup. T1 and T2 are not implemented;
ordinary constrained calls still use a fresh Z3 context, and the requested
per-class incremental context cache remains unimplemented.

The opt-in `IVL_PERF_STATS=1` report counts T0 returns and classifies the
remaining current fresh-Z3 calls into ordinary hard-constraint (T3-eligible)
and full-solver (T4) buckets. T3 here means eligible for the proposed
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
