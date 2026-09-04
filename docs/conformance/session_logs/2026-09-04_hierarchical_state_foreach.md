# Hierarchical state foreach constraints — 2026-09-04

The OpenTitan xbar sequence uses
`foreach (xbar_devices[device_id].addr_ranges[i])` inside an inline class
constraint. The old converter deliberately rejected this shape: falling
through to lookup of `xbar_devices` alone would iterate the wrong array.
The package-struct reducer demonstrated a warning followed by a forbidden
random address. The implementation now captures the selected owner after
`pre_randomize`, reads that owner's queue, and expands the constraint over
its current elements before solving.

## Normative contract

| Behavior | IEEE 1800-2017 | IEEE 1800-2023 |
|---|---|---|
| Hierarchical iterative constraints, iterator scope/type, state index expressions, size-before-element ordering | 18.5.8.1; 12.7.3 | 18.5.7.1; 12.7.3 |
| Error sifting in constraint guards | 18.5.13 | 18.5.12 |
| State and random variables; invalid X/Z values | 18.3 | 18.3 |
| Inline target-first lookup and with-identifier lists | 18.7.1 | 18.7.1 |
| Failure return/writeback; randomization hooks | 18.6.1; 18.6.2 | 18.6.1; 18.6.2 |
| Ternary common width/sign and signed numeric indices | 11.6.1; 11.8.1; 11.8.2 | 11.6.1; 11.8.1; 11.8.2 |
| Division/modulus by zero produces X | 11.4.3 | 11.4.3 |
| Queue receiver selection and invalid indexed writes | 7.10.1 | 7.10.1 |
| Local/protected class-member visibility | 8.18 | 8.18 |

The local LRMs were read directly. Slang 11.0.448 provides independent
accept/reject comparisons; its behavior is not the normative decision rule.
Clause 18 remains **PARTIAL**.

## Implementation and boundaries

The parser already retains the selected array prefix and member. No grammar
change is needed. The converter recognizes the complete field path before
ordinary scalar capture can bind an iterator to a same-named caller variable.
It retains target-first lookup: a target declaration that cannot yet be
resolved through this path remains diagnosed, while a with-identifier list
can legitimately select caller state. Class-field lookup checks visibility.

The new `%randomize/with/objects` instruction has independent scalar and
object counts. The target duplicates the solver receiver before evaluating
object slots, so these slots cannot replace the object used for solving or
for the conditional post hook. The old instruction remains unchanged for
calls with no object slots.

`qforeach` carries an owner slot and queue property id. Capturing the owner
preserves the difference between a null selected device and a valid device
with empty queue storage. Field projection reuses the runtime class/struct
layout. The expander uses the existing IR parser and typed Z3 evaluator;
it carries evaluation errors until the enclosing guards are resolved.
Active rand properties remain solver variables, while inactive target state
and caller values retain their current values. Failed expansion returns zero
without entering a solve or calling the post hook. A successful empty
iteration imposes no element constraints.

Typed ternaries retain both arms for width/sign calculation even when a
state predicate selects one arm. Signed narrow negative indices remain
negative. Dynamic-array foreach templates elsewhere in the same with-clause
are structurally checked and preserved for the existing size/element solver
passes; their iterator does not become an index into the state queue.
Unknown operators and malformed interpreted metadata are diagnosed.

The evidenced new shape is an inline class constraint over a caller/package
state collection selected by the stored simple prefix identifiers, whose
queue/dynamic-array member contains class handles or unpacked structs and
whose referenced fields are packed integral values up to 64 bits. Nested
hierarchical templates, target-object roots/selectors requiring additional
resolution, other loop-dependent paths, wider or non-integral fields, and
general scope-form hierarchical foreach are still explicitly unsupported.
This is not full clause-18 closure.

## Prerequisite assignment defect

The reducer's `devices[1].ranges = ...` reached an existing queue-store bug.
`prop_lval_index_expr_` reused the enclosing receiver index as a property
index. That wrote the whole queue as one element. The object queue's sparse
fallback then looped without growing the queue, so it never terminated.
The property selector now uses only its own index. A write beyond `$+1`
warns and leaves the object queue unchanged, matching 7.10.1. The regression
checks both struct and class receivers and an invalid object-queue write.

## Permanent regressions

Each source below has paired 2017/2023 legacy and JSON registrations with
exact output expectations:

- `sv_constraint_foreach_selected_queue`: repeated narrow-band enforcement,
  selected-device changes, queue resize/empty state, pre/post hooks, UNSAT
  rollback, iterator shadowing, struct/class shapes, and with-identifier lookup.
- `sv_constraint_foreach_index_signed`: signed foreach indices and signed
  ternary extension in the shared solver path.
- `sv_constraint_foreach_state_guards`: ternary width/sign, guarded invalid
  reads, inactive target properties, explicit active sets, and mixed random
  and state foreach templates.
- `sv_constraint_foreach_state_errors`: signed-negative index, zero divisor,
  X state, null element/owner, guarded null reads, and failed-solve state.
- `sv_queue_selected_receiver_assign`: whole-queue assignment through a
  selected receiver and warning/no-mutation for invalid object-queue writes.
- `sv_constraint_foreach_selected_unsupported`: target-selector lookup
  boundary remains a warning and scope-form unsupported use remains hard.
- `sv_constraint_foreach_member_access`: private/protected access is rejected.

`tests/vvp_runtime/run_state_foreach_invariants.py`, connected to the main
gate, checks 15 malformed constant/operator/slot/receiver/stack cases.

## Review and validation state

Fresh-context design and implementation review exposed concrete defects
before the gate. The user-requested Claude Code CLI review is complete and
reconciled in `evidence/clog2-xbar-codex-arm64-20260904/claude-xbar-reconciliation.md`.
Its mixed-foreach finding reproduced and was repaired. An ERROR implication
guard remains an error even with a TRUE consequent: the LRM defines guards
as constraint-creation predicates, not interchangeable solver relations.

The first broad gate was stopped during UVM after the mixed-foreach review
reducer reproduced. It is superseded by the complete gate on the final
repaired build8 candidate (`xbar-full-gate2.log`, `XBAR_GATE_DONE=0`):

| Final gate | Result |
|---|---:|
| Legacy ivtest | **4551/4556, 0 failed**; 2 NI, 3 EF; name-diff clean |
| Full JSON/VVP | **1445/0** |
| VPI | **103/103** |
| Negative tests | **149/0** |
| Raw state-foreach runtime invariants | **15/15**; other runtime invariants pass |
| Real-DPI UVM | **355/0/0** |

Both focused harnesses passed **14/14** after the mixed-foreach repair.
The final Darjeeling debug xbar compile no longer emits its former constraint
warning. Compiler and runtime fingerprints remained fixed throughout validation.

## Application census and isolation

The complete 300-second OpenTitan census contains all **530** rows. The
per-core diff records **195→210 PASS**, **33→17 DEBT**, and no lost PASS or
changed inputs. All eight xbar compile rows became PASS; seven runtime rows
became PASS and Darjeeling-main became RUNTIME_TIMEOUT. ADC changed from
RUNTIME_FAIL to RUNTIME_TIMEOUT. Sequential isolated replays used the same compiled images, arguments and
300-second bounds: ADC completed in **116.449s**, matching all baseline
metrics and the complete output-line multiset (register dump order differed);
Darjeeling-main completed in **109.677s**, matching baseline metrics and its
complete output payload exactly. The timeouts were not reproduced in isolation.
No functional regression was observed after these checks. The original census
remains unchanged at 210 PASS; successful isolated replays are separate evidence,
not replacements for its recorded outcomes.

Summed `semantic_debt_count` is **2245→2223**. Twenty actual xbar constraint
warnings disappeared: sixteen xbar rows and four enclosing Darjeeling/Earlgrey
chip rows. Two additional counted-line reductions arise from interleaved AES
and entropy-source macro diagnostics. All macro warning/error token totals
and return codes match; no macro problem was fixed or hidden. The only other
changed runtime metrics belong to the two timeout cases.

Evidence under `evidence/clog2-xbar-codex-arm64-20260904/`:
`opentitan-xbar-300s-diff.json`, `opentitan-xbar-300s-audit.json`,
`adc-xbar-isolated-runtime.json` and `darjeeling-main-xbar-isolated-runtime.json`
plus `adc-isolated-output-proof.json` and
`darjeeling-main-isolated-output-proof.json`. Original census outputs
remain under `evidence/opentitan-xbar-300s-after254-arm64-20260904/`.

Caliptra's new 300-second census preserves **52 PASS / ICARUS_GAP 0**.
All 105 job classifications, input fingerprints and tool diagnostic metrics
match the clog2 checkpoint (`caliptra-xbar-300s-diff.json`). Inputs remain
OpenTitan `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`, Caliptra
`bd31614182fb56e55578f48086a10ded650434fd` and AdamsBridge
`e59eba955eac2a1adcb059f250641ede78e304be`.

These censuses do not establish full DV success. In particular, all eight baseline xbar runtime logs and all completed candidate
xbar runtime logs (including the isolated main replay) report **zero scoreboard
items**. Their pass banners are insufficient evidence of meaningful traffic or coverage;
that pre-existing limitation requires further investigation. The permanent
reducers independently prove repeated constraint enforcement.

All runs use the worktree's installed native ARM64 tools and the
user-authorized 300-second CPU guard. No OpenTitan, Caliptra, AdamsBridge, or
UVM source is adapted. All old worktrees remain retained.
