# Blockers registry (Level 3 — operational backlog)

This file is a **backlog**, not an authorization to implement. Per
`AGENTS.md`, only `.ai/ACTIVE_WORK.yaml` (status: `in_progress`, naming a
blocker ID from this file) authorizes implementation work. Reading a row
here as "next" and starting to code is exactly the failure mode this file
exists to prevent.

This is a **seed set**, not a migrated copy of `iverilog_uvm_blocker_audit.md`
/ `blocker_inventory.json` (134 grouped entries). Those documents remain the
fuller inventory; entries here were promoted because they have concrete
source/recorded evidence and a plausible closure test. Promote additional
rows from the audit into this format as they are picked up — do not bulk
import.

## Status vocabulary

| Status | Meaning |
|---|---|
| `OPEN` | Identified, not yet reproduced on current HEAD. |
| `REPRODUCED` | A current-HEAD failing reducer exists. |
| `IN_PROGRESS` | An `.ai/ACTIVE_WORK.yaml` ticket currently targets this ID. |
| `BLOCKED` | Requires architecture change or a decision beyond scope lock; see its entry for what's blocking. |
| `CLOSED` | Fixed, tested, and documented per the manifesto's Definition of Done. Record the closing PR. |
| `WONTFIX` | Deliberately out of scope (e.g. illegal-source rejection working as intended); record why. |

## Confidence vocabulary (carried from the audit)

`SOURCE` (inspected implementation path), `RECORDED` (a repo record/PR
states it — re-verify before implementing, some are stale), `QUALIFICATION`
(missing evidence for a claimed scope, not a proven wrong result),
`UNRESOLVED` (record explicitly leaves it tentative), `ARCHITECTURE`
(requirement for a future declared capability, not a reproduced defect).

## Entry format

```markdown
### <ID> — <title>

- **Area / edition:** <e.g. Randomization / edition-agnostic>
- **State:** OPEN | REPRODUCED | IN_PROGRESS | BLOCKED | CLOSED | WONTFIX
- **Confidence:** SOURCE | RECORDED | QUALIFICATION | UNRESOLVED | ARCHITECTURE
- **Evidence / reproducer:** <file:line, PR #, or session log pointer; a
  reducer path once one exists>
- **What it blocks:** <application workload / qualification claim / clause>
- **Closure requirements:** <what a CLOSED verdict must demonstrate>
- **Last verified revision:** <commit sha, or "not re-verified since audit">
```

---

### U01 — Xbar runtime/scoreboard/outstanding-request failures

- **Area / edition:** UVM and applications / edition-agnostic
- **State:** OPEN (checked traffic completes; pinned workload/UVM teardown qualification remains)
- **Confidence:** REPRODUCED
- **Evidence / reproducer:** `docs/conformance/session_logs/2026-09-04_global_constraint_solver.md`
  (5 xbar runtime logs show scoreboard mismatches; all 8 report outstanding
  requests on termination); PR #258; PR #261 (enum fix is explicitly not
  evidence these are fixed). No reducer exists yet — the session log notes
  the targeted probe hit the 300s CPU guard before completing.
- **What it blocks:** Real xbar application-level DV evidence; any claim of
  "OpenTitan xbar works."
- **Closure requirements:** Reproduce the first divergence with a bounded
  probe, reduce the simulator mechanism it exposes, and demonstrate at least
  one xbar smoke reaching normal completion with matched, checked
  request/response traffic and zero outstanding transactions at end of test.
- **Last verified revision:** `53b58890c` (P04): fresh smoke plus2repeats all complete115requests/230checked scoreboard items,4SEQPRTZMBwarnings,0errors/fatals and TEST FAILED CHECKS. All360exported source files match the prior replay. P04 fixes its independent live-parent kill reducer; it does not qualify U01. Pinned workload settings select UVM1.2, campaign library2020.3.1; no library edit or warning suppression. Evidence: `campaign-20260908/u01-after-p04`.

### Z01 — Joint solve-before stages unsupported

- **Area / edition:** Randomization / edition-agnostic
- **State:** OPEN
- **Confidence:** SOURCE
- **Evidence / reproducer:** `vvp/vvp_z3.cc` explicitly rejects
  `order_pairs` in the joint route ("solve before stages across objects are
  not supported"); PR #258.
- **What it blocks:** Any DV workload using cross-object `solve ... before`
  ordering under the joint solver (recorded as a shared xbar/runtime
  frontier in the same session log as U01).
- **Closure requirements:** Small-domain staged distributions with correct
  marginal/conditional probabilities and graph rollback on failure; explicit
  rejection preserved for shapes still out of scope after the fix.
- **Last verified revision:** b9de0be7f reproduced both editions. Z01A resolves bounded canonical integral stages locally; ordered dist/randc and non-scalar/large-domain cases remain open.

### C01 — Untranslated inline constraints are discarded (semantic degradation)

- **Area / edition:** Frontend/randomization / edition-agnostic
- **State:** CLOSED (silent-discard defect only; local implementation unmerged)
- **Confidence:** REPRODUCED
- **Evidence / reproducer:** `make_randomize_with_expr()` in `elab_expr.cc`
  warns and continues when an inline constraint cannot be lowered, instead
  of hard-erroring — the call can be built without the requested constraint.
- **What it blocks:** Trustworthiness of any `randomize() with { ... }` call
  whose constraint shape isn't recognized; a silent-degradation risk, not
  merely a missing feature.
- **Closure requirements:** Reduce a live unsupported inline-constraint
  shape; require either correct constraint execution or an explicit failure
  — never a successful solve that silently dropped the constraint.
- **Last verified revision:** 8f298eefe accepts and discards a selected foreach item in both editions; runtime returns success with 412736472 instead of required 123. Candidate passes all required local gates and review; remote CI required before merge. Unsupported expressions remain unimplemented.

### S01 — Cross-clock overlapping implication (SVA boundary)

- **Area / edition:** Assertions/SVA / IEEE 1800-2017 and 1800-2023 16.13.3.
- **State:** SUPERSEDED (bounded fixed-chain boundary already implemented).
- **Confidence:** VERIFIED
- **Evidence / reproducer:** Commit `0ff77277c` implements the fixed-chain
  overlapping boundary. Fresh `../evidence/campaign-20260908/s01/` runs cover
  coincident edges in both source orders, strictly later consequent ticks,
  positive/negative outcomes, preponed sampling and nested clock flow.
  Three reducers pass in both editions with default and legacy SVA modes
  (12 runs); independent review confirms this bounded classification.
- **Residual scope:** Variable-length antecedents and broader multiclock
  properties remain separate obligations; this is not complete SVA qualification.
- **Last verified revision:** `2be79b2c0`; existing clock-flow/nested-flow
  regressions also pass the required integrated suite. No implementation change.

### V01 — Exact merged type-coverage bin universe (coverage correctness)

- **Area / edition:** Functional coverage / edition-agnostic
- **State:** OPEN (V01A resolves bounded dynamic value-bin union locally)
- **Confidence:** REPRODUCED
- **Evidence / reproducer:** `vvp/class_type.cc`'s `type_coverage` uses a
  maximum registered dynamic-family size raised to the hit count — not an
  exact union for arbitrary disjoint instance bin sets.
- **What it blocks:** Correct type-coverage denominators/percentages for
  class-type coverage with disjoint or partially overlapping instance bin
  sets; any claim of coverage-number correctness beyond the all-hit case.
- **Closure requirements:** Disjoint and overlapping instance domains with
  known union sizes, including partial (non-100%) coverage results checked
  against a hand-computed oracle, not just "coverage reaches 100%."
- **Last verified revision:** 9218751e2; paired LRM19.11.3 overlapping-range reducer returns100 rather than66.666667 percent. Evidence/campaign-20260908/v01/union.sv.

### F00 — Hardware formal proof backend (PROGRAM item, not a bug)

- **Area / edition:** Formal verification / N/A
- **State:** OPEN
- **Confidence:** ARCHITECTURE
- **Evidence / reproducer:** `docs/conformance/iverilog_ieee1800_uvm_manifesto.md`
  places a proof engine in a later program; the audit's F01–F09 rows (sound
  transition-system lowering, property roles, bounded/unbounded search,
  counterexample replay, vacuity checks, backend soundness validation) are
  facets of this one program, not nine independent reproduced defects.
- **What it blocks:** Any claim of formal/model-checking capability beyond
  constrained-random Z3 solving for randomization (which is explicitly not a
  hardware model checker).
- **Closure requirements:** A published supported profile (finite state,
  legal constructs, reset/clock/X-Z treatment) plus a sound lowering,
  bounded-safety/cover search, and soundness qualification against known
  passing/failing designs — this is a multi-increment program; do not close
  it as one PR. Track F01–F09 as its sub-items when work actually starts.
- **Last verified revision:** N/A (architecture item).

---

## Excluded / already reconciled (do not re-open without new evidence)

These were checked during the audit that seeded this file and found to be
stale or already addressed — listed so they aren't accidentally re-promoted
from `blocker_inventory.json` as if still open:

- One-bit enum VPI-format assertion — fixed by merged PR #261.
- "Joint parent/child constraints entirely missing" — PR #258 implements a
  bounded joint route; only its residual contract (Z01 above, and the
  other Z02–Z14 rows in the fuller audit) remains open.
- "Solver UNKNOWN accepted as a successful model" — `vvp_z3.cc` returns
  failure and rolls back on UNKNOWN; an old lenient-UNKNOWN note is stale.

See `blocker_inventory.json` / `iverilog_uvm_blocker_audit.md` (as supplied
to the governance-bootstrap session) for the full 134-row inventory this
seed set was drawn from, and for the complete excluded/reconciled list.

## Campaign-resumed process work

### P01 — Null and empty parallel children are discarded

- **Area / edition:** Process execution / IEEE 1800-2017 and 2023 §9.3.2.
- **State:** CLOSED (bounded local implementation; not merged)
- **Prerequisite:** P03 resolved and locally validated at b9ffa4994. Reducers resumed from preserved Git stash.
- **Confidence:** SOURCE
- **Evidence / reproducer:** Existing fork-process-preservation patch; `ivtest/ivltests/sv_fork_null_child.v` and `sv_fork_empty_child.v` (current baseline verification pending).
- **What it blocks:** Correct join_any termination and process creation for empty children.
- **Closure requirements:** Correct join/join_any/join_none behavior; preserve sequential/assertion null actions; focused and integrated gates.
- **Last verified revision:** Campaign P01 checkpoint on b9ffa4994; all required local gates passed. See 2026-09-08 campaign evidence; closing PR/remote CI pending before merge.

### P02 — Singleton forks lose process identity

- **Area / edition:** Process execution / IEEE 1800-2017 and 2023.
- **State:** CLOSED (bounded local implementation; not merged)
- **Confidence:** SOURCE
- **Evidence / reproducer:** Preserved original worktree `sv_fork_singleton_process.v`; `dll_target::proc_block` flattens singleton joins.
- **What it blocks:** Process identity/control and per-child random stability.
- **Closure requirements:** Process identity, RNG ownership, suspend/resume/kill and task/sequential controls with required gates.
- **Last verified revision:** Campaign P02 checkpoint on a5788c259; all required local gates passed. See 2026-09-08 campaign evidence; closing PR/remote CI pending before merge.

### P03 — Function-spawned fork children execute synchronously

- **Area / edition:** Process execution / IEEE 1800-2017 and 2023.
- **State:** CLOSED (bounded local implementation; not merged)
- **Confidence:** SOURCE
- **Evidence / reproducer:** Preserved original worktree `sv_fork_function_children.v`; `do_fork_` function path can synchronously execute non-final children.
- **What it blocks:** Background process scheduling in functions.
- **Closure requirements:** Child execution starts after parent suspension/termination, including multiple children; required gates.
- **Last verified revision:** Campaign P03 checkpoint based on 49505f514; see 2026-09-08 campaign evidence. All required local gates passed; closing PR/remote CI pending before merge.

### Z01A — Bounded canonical integral joint ordering stages

- **Area / edition:** Randomization / IEEE 1800-2017 18.5.10, 2023 18.5.9.
- **State:** CLOSED (bounded local implementation; unmerged)
- **Parent:** Z01 (remains open beyond this bounded subcase).
- **Confidence:** REPRODUCED
- **Evidence / reproducer:** exact_joint rejects all order_pairs at current b9de0be7f; root-local ordering in existing sv_randomize_global_sampling_fail is legal but unsupported.
- **What it blocks:** Ordered small-domain parent/member-object sampling.
- **Closure requirements:** Exact stage projections, latest partial ordering, rollback, replay, callbacks/activation and required gates; keep ordered dist and non-scalar stages explicit unsupported.
- **Last verified revision:** b9de0be7f red reducer in both editions; candidate patch passes all required local gates and independent review; remote CI/merge pending.


### L01 — Procedural member foreach replaces a selected prefix with a new loop

- **Area / edition:** Procedural iteration / IEEE 1800-2017 and 2023 12.7.3.
- **State:** CLOSED (bounded local scope; remote CI required before merge)
- **Confidence:** REPRODUCED
- **Parent:** U01, preserved under evidence/campaign-20260908/u01.
- **Evidence / reproducer:** lookup.sv fails both editions at c57fbe3c5; inner foreach visits all device ranges despite an enclosing selected-device filter. Slang accepts both editions; Verilator runtime produces correct membership.
- **What it blocks:** Correct selected member iteration and unmodified xbar scoreboard address routing.
- **Closure requirements:** Correct terminal-only loop declarations/iteration, constant/variable/nested controls, Bison/focused/integrated gates and independent review; then replay U01.
- **Last verified revision:** b0ac00f47 passes paired/focused/integrated/full JSON/UVM and review. Unmodified U01 replay confirms corrected routing with four request checks and three matched responses; application remains open for its pre-existing fourth-response stall.

### L02 — Automatic block locals retain values across loop entries

- **Area / edition:** Lifetime / IEEE 1800-2017 and 2023 6.21, 6.8.
- **State:** CLOSED (bounded local scope; remote CI before merge)
- **Confidence:** REPRODUCED and ROOT_CAUSED
- **Parent:** U01; preserved contract and two-edition reducer in evidence/campaign-20260908/u01-loop.
- **Evidence:** Class-task for-loop bit local returns 1 on entry 2 instead of default 0. Emitted autobegin.shared stores it in the task frame. Same driver structure leaves rsp_done set after the first response.
- **Closure requirements:** Fresh per-entry storage/defaults with static and capture controls; required local gates, review and U01 replay.
- **Last verified revision:** e0dab7221 red in both editions. Candidate now passes 93 legacy / 50 JSON focus and make check, including automatic_events2, ancestor history 2,3, and recursive event ownership (prior UVM deadlock repaired). Independent review has no actionable finding. All local semantic gates pass: integrated4666/4661/0/2/3, VPI103, negative149, runtime15, JSON1558/0, UVM355/0/0 real DPI. Unchanged U01 replay on9218751e2 completes115 requests/230 checked items; zero errors/fatals. Four sequence-parent warnings still prevent application qualification.

### V01A — Exact constructor-dependent value-bin union

- **Area / edition:** Coverage / IEEE1800-2017 and2023 19.11.3.
- **State:** CLOSED (bounded local scope; remote CI before merge)
- **Parent:** V01; no complete type-option or arbitrary cross/transition universe claim.
- **Confidence:** REPRODUCED and ROOT_CAUSED
- **Evidence:** Paired sv_covergroup_merged_value_union; original LRM example returned100 instead of66.666667.
- **Implementation:** Register and merge resolved intervals for unsized value bins; preserve name/index identity for scalar/fixed bins. Unsampled and retired instances remain represented.
- **Validation:** Focus53/43, integrated4668/4663/0/2/3, VPI103, negative149, runtime15, JSON1560/0, real-DPI UVM355/0/0, make check and independent review passed.
- **Limits:** Default merge_instances weighted averaging and downstream huge-total saturation remain unqualified.

### V02 — Default type coverage silently merges instances

- **Area / edition:** Coverage / IEEE1800-2017 and2023 19.11.3, table19-3.
- **State:** CLOSED (bounded local scope; remote CI before merge)
- **Confidence:** REPRODUCED
- **Evidence:** evidence/campaign-20260908/v02/average.sv, both editions on6eee0480c return100 rather than50 for two equal-weight half-covered instances.
- **What it blocks:** Trustworthy default type coverage; current result falsely reports complete coverage.
- **Closure requirements:** Respect default/explicit merge mode and instance weighting with paired controls, complete required gates and independent review.
- **Last verified revision:** ac60732f3 implements default weighted instance averaging and explicit merged/public-instance dispatch with native typed option initialization. Focus65/55, integrated4680/4675/0/2/3, VPI103, negative149, runtime15, full JSON1572/0, real-DPI UVM355/0/0, make check and independent review pass.
- **Limits:** Parent V01 remains open. General type_option weighting, procedural static type-option assignment, goals/strobe and arbitrary cross/transition universes are not qualified by this increment.

### V03 — Overall coverage ignores covergroup type weights

- **Area / edition:** Coverage / IEEE1800-2017 and2023 19.7.1 table19-3,19.9,19.11.
- **State:** CLOSED (bounded local scope; remote CI before merge)
- **Confidence:** REPRODUCED and ROOT_CAUSED
- **Evidence:** evidence/campaign-20260908/v03/type-weight.sv; both editions onac60732f3 return75 instead of87.5 for scores50/100 with type weights1/3.
- **What it blocks:** Correct overall coverage; declared type priority is silently ignored.
- **Causal trace:** of_COVGRP_GET_ALL computes an unweighted arithmetic mean; group type-weight metadata is absent.
- **Closure requirements:** Exact group-level type weights, default/zero/eligibility controls, valid constant conversion, all required local gates and independent review.
- **Limits:** Coverpoint/cross type weights and procedural static option access remain separate obligations.
- **Last verified revision:** 2be79b2c0 implements group-level declared type weights in overall coverage. Focus75/65, integrated4690/4685/0/2/3, VPI103, negative149, runtime15, full JSON1582/0, real-DPI UVM355/0/0, make check and independent review pass. Separate type-weight tag preserves old bytecode/property ordering.

### S02 — Bounded variable-length multiclock antecedents

- **Area / edition:** SVA / IEEE 1800-2017 and 1800-2023 16.12.7, 16.13.3.
- **State:** SUSPENDED — attempt-identity design boundary; reducer retained.
- **Confidence:** REPRODUCED compile rejection at `2be79b2c0` in both editions.
- **Evidence:** `../evidence/campaign-20260908/s02/antecedent.sv` and paired
  compile logs; legal `a[*1:2] |=> @(posedge c2) b` is rejected.
- **Mechanism:** Two-domain and N-domain callers of `sva_mc_expand_chain_`
  require fixed antecedents. Mere request-count expansion does not establish
  the per-start implication verdict required when several endpoints match.
- **Closure:** Preserve each endpoint evaluation, aggregate truth and required
  action semantics, clock timing, sampling and cancellation for the exact
  claimed bounded subset. Corrected expectation is two failures for two starts,
  rather than three failures for three endpoints.

S02 coordination boundary: scalar cross-clock request counts erase the parent
identity needed for one verdict per starting attempt. A local count-only fix is
incorrect. Reusing NFA endpoint bookkeeping first requires correcting its
existing per-consequence verdict dispatch; S03 is selected independently on a
fresh wrong-result reducer. A future S02 design must preserve attempt identity,
open antecedent status and outstanding consequences across clock domains;
architecture expansion is not authorized by this suspension.

### S03 — NFA implication verdicts are emitted per endpoint

- **Area / edition:** SVA / IEEE 1800-2017 and 1800-2023 16.12.7.
- **State:** LOCALLY VALIDATED — remote CI required before merge.
- **Evidence:** `../evidence/campaign-20260908/s03/attempt-verdict.sv` fails
  both editions at `2be79b2c0`: one start with two failing consequences emits
  two failure actions instead of one. Independent semantic review confirms.
- **Mechanism:** `pform_sva_nfa_try_assertion` dispatches each consequence
  verdict directly and releases antecedent slots without retaining parent
  verdict identity. Existing endpoint-fanout golds encode this defect.
- **Closure:** Aggregate consequence outcomes per attempt, including early
  failure, delayed success, vacuity, cancellation and end-of-simulation;
  retain independent endpoints and local snapshots. Correct affected golds
  only from reviewed semantics and run required gates.

S03 result: existing NFA endpoint fanout retains parent identity through all
consequences; one child failure terminates the parent once, and success waits
for antecedent closure and all child successes. Vacuous user actions, distinct
nonvacuous callbacks, local snapshots, same-tick slot reuse, disable/kill,
cover counts and parent-counted strong EOS are covered. All required local
gates/review pass: NFA58, focus55/20, integrated4692/4687/0/2/3,VPI103,
negative149,runtime15,JSON1584,real-DPI UVM355,make check. Finite cyclic-pool
limits, DD005 nonfanout vacuity, S02 multiclock identity and broader SVA/formal
qualification remain open. Evidence: campaign-20260908/s03.

### S04 — Missing vacuous user pass actions in single-clock implications

- **Area / edition:** SVA / IEEE1800-2017 and1800-2023 16.12.7,16.14.1.
- **State:** LOCALLY VALIDATED — required local gates and independent review pass; remote CI remains required before merge.
- **Evidence:** At locally validated61ca5f336, false antecedent `a |-> b`
  produces0pass/0fail instead of1pass/0fail in2017/2023, default/legacy modes.
  Four compile/runtime logs and reducer in campaign-20260908/s04.
- **Mechanism:** Nonfanout NFA dead-before-obligation path suppresses pass
  dispatch; legacy match-only injection loses vacuous attempts. Specialized
  callers use the same pass dispatcher; fixed/OR/AND progress and symbolic
  pre-match ages preserve first-loss vacuity. Unsampled and asynchronous
  cancellation includes nonunit integral true values.
- **Validated so far:** Four paired reducers, VPI callback distinction,
  focused legacy17/17, JSON8/8, NFA58/58, affected real-DPI UVM9/9, make check
  and independent code review. Full integrated4700/4695/0/2/3, VPI104/104,
  negative149/149, runtime15/15, JSON1592/0 and real-DPI UVM355/0/0 pass.
- **Limits:** DD-007 symbolic nonvacuous per-endpoint verdict behavior remains
  separate and unqualified; no complete parent-feature claim.
- **Closure:** Correct vacuous user actions per attempt while preserving sampling,
  cancellation, multiplicity, callback distinctions and S03 parent semantics;
  all required local gates and independent review, then remote CI before merge.


### S05 — Symbolic repetition implication parent verdicts

- **Area / edition:** SVA / IEEE1800-2017 and1800-2023 16.9.2,16.12.7,16.14.1.
- **State:** LOCALLY VALIDATED — reviewed S05 parent correction; remote CI required before merge.
- **Evidence:** One enabled start of a[*LO:HI] with overridden LO2/HI3 produces
  good1/0 and bad0/1 at length2, then good2/0 and bad0/2 at length3 in both
  editions. Correct parent results are early good0/0,bad0/1 and final
  good1/0,bad0/1. Reducer/logs: campaign-20260908/s05.
- **Mechanism:** Symbolic r_end/r_fire counts publish consequent endpoint
  actions directly, rather than retiring failed parents and waiting for
  antecedent closure before success. Current packed ages/mature counts must
  retain the necessary ownership without an arbitrary new cap.
- **Selection:** Standards correctness and parameterized application assertion
  relevance; this is a distinct symbolic engine from S03's qualified NFA path.
- **Scope:** Accepted symbolic consecutive-repetition implication paths,
  existing cancellation/sampling/Reactive behavior, empty/nonempty timing and
  repetition-bound overrides. DD-006, symbolic consequent-delay overrides DD-008,
  and S02 remain separate.
- **Closure:** Reviewed parent-verdict semantics with permanent regressions and
  all required local gates; remote CI remains required before merge.

- **S05 current validation:** Paired focus14/14 legacy+JSON in both engines;
  neighbor17/17+8/8, callback1/1, NFA58/58, make check0 and independent review
  pass. Full integrated4714/4709/0/2/3, VPI105, negative149, runtime15,
  JSON1606/0 and real-DPI UVM355/0/0 pass. This qualifies accepted symbolic
  consecutive repetitions with fixed ##0/##1 Boolean consequences and tested
  exact-window empty timing, not all SVA or symbolic consequent-delay overrides.


### S06 — Overridden symbolic SVA cycle delay is frozen to its default

- **Area / edition:** SVA and parameter elaboration / IEEE1800-2017 and1800-2023.
- **State:** LOCALLY VALIDATED — reviewed S06 delay correction; remote CI required before merge.
- **Evidence:** On validated a76c9f67a, LO1/HI2/D0 defaults with D1 override
  pass at tick2 and ignore a false final child at tick3 in both editions.
  Literal ##1 controls pass. Reducer and paired logs: campaign-20260908/s06.
- **Hypothesis:** Single-delay grammar folds a parameter default through
  pform_sva_const_long and deletes its expression; range-delay syntax already
  retains overridable expressions for ordinary instance elaboration.
- **Selection:** Silent timing miscompilation, ordinary parameter override
  correctness and parameterized application assertion relevance.
- **Scope:** Shared single-delay normalization and necessary instance-sized
  lowering; exact parent, cancellation, sampling and empty timing preserved.
  No new arbitrary delay cap or broader multiclock architecture.
- **Closure:** Paired semantic regressions, override/boundary controls,
  required full gates and independent review. Remote CI before merge.

- **S06 repaired scope:** Single named parameter/localparam cycle delays retain
  per-instance values. Delayed sampled histories align symbolic repetition
  endpoints with the current consequent; unmatched real-time ages retain
  vacuity. Direct/prefixed overlap/nonoverlap, bounded/unbounded parents,
  empty timing, cancellation and cover endpoint counts have paired controls.
  Shared self-sizing preserves substituted operand width/sign; invalid
  original negative grouped delays and unknown bounds reject per instance.
- **S06 remaining scope:** Arbitrary delay-expression parsing, broader formal
  lookup, unsupported composed/multiclock shapes and maximal-width arithmetic
  remain unqualified. A rejection control does not implement a legal shape.
- **S06 current validation:** Focus18/18 legacy+JSON in both engines;
  S05neighbors14/14+14/14,S04neighbors17/17+8/8; NFA58/58;
  integrated4732total4727pass0fail2NI3EF,VPI105,negative149,runtime15;
  JSON1624/0,real-DPIUVM355/0/0,makecheck and final source/test review pass.

### S07 — Nested parameterized sequence aliases fail expansion

- **Area / edition:** Sequence composition / IEEE1800-2017 and1800-2023.
- **State:** LOCALLY VALIDATED — reviewed nested-alias increment; remote CI required before merge.
- **Evidence:** campaign-20260908/s04/window-nested-alias.sv; Left/Right
  wrapping Pair(actuals) reports No function named Pair, while direct use
  works. Previously reproduced on61ca5f336; current-source check pending.
- **Scope:** Shared nested sequence expansion and actual binding; preserve
  lexical identity, recursion safeguards, temporal truth and ownership.
- **Closure:** Paired reducer/direct controls, permanent timing/binding tests,
  all required local gates and review; remote CI before merge.

- **S07 exact qualification:** Bare alias bodies recursively expand nested
  sequence calls in their declaration generate scope. Caller-supplied
  sequence actuals retain caller lookup. Active-path cycles reject before
  expansion; repeated legal uses retain independent cloned bodies.
- **S07 validation:** Paired focus12/12 legacy+JSON in both engines;
  S06neighbors18/18+18/18,S04neighbors17/17+8/8,NFA58/58;
  integrated4744total4739pass0fail2NI3EF,VPI105,negative149,runtime15;
  JSON1636/0,real-DPIUVM355/0/0,makecheck and final review pass.
- **S07 residuals:** Full dependency-graph validation across independent
  instances and pre-existing parameterized declaration-owned lookup remain
  unqualified; no general sequence-composition completion claim.

### L03 — Automatic Boolean event expressions share activation state

- **Area / edition:** Lifetime/events / IEEE1800-2017 and1800-2023 6.21,9.4.2.
- **State:** LOCALLY VALIDATED — reviewed Boolean activation state and supported input chains; remote CI before merge.
- **Evidence:** u01-loop/history-expression-preexisting.sv; two automatic
  invocations of posedge(value[2] | 1'b0) both trigger at2 instead of2,3.
  Freshly reproduced after validated L04 in both editions; mixed parent/local
  OR also wakes2,2 instead2,3 (evidence/l03/after-l04-* and mixed-*).
- **Scope:** Shared Boolean driver activation state/context and directly
  necessary selection, preserving existing runtime lifetime mechanisms.
- **Closure:** Paired reducer and lifetime/static controls, all required
  local gates and review; remote CI before merge.

- **L03 validation:** Paired focus12/12legacy+JSON,L02neighbors93/50,
  L04neighbors4/4,PART_PV ancestor history/reuse,NFA58/58,integrated4760total
  4755pass0fail2NI3EF,VPI105/105,negative149/149,runtime invariants,
  JSON1652/0,real-DPIUVM355/0/0,makecheck and final review pass.
- **L03 residuals:** BUF,NOT,mux and other expression families remain
  unchanged/unqualified; no general expression or application closure.

### L04 — Automatic integral defaults do not seed event history

- **Area / edition:** Lifetime/events / IEEE1800-2017 and1800-2023 6.8,6.21,9.4.2.
- **State:** LOCALLY VALIDATED — reviewed integral initialization prerequisite; remote CI before merge.
- **Evidence:** Paired current4a879babc default-negedge reducer fires at1 on
  unchanged partial zero write instead of actual negedge at3; evidence/l04.
- **Mechanism:** Integral slot reset sets storage without initial publication;
  current hooks precede context stack/live linkage.
- **Scope:** Post-link hook using existing activation infrastructure and
  automatic integral initial-value propagation, all allocation callers audited.
- **Closure:** Paired default/lifetime controls and all required gates/review;
  resume L03 only after validated baseline. Remote CI before merge.

- **L04 validation:** Paired focus4/4 legacy+JSON,L02neighbors93/93+50/50,
  mixedlifetime7/7+7/7,eventcontrols14/14+14/14,NFA58/58;
  integrated4748total4743pass0fail2NI3EF,VPI105,negative149,runtime15;
  JSON1640/0,real-DPIUVM355/0/0,makecheck and final review pass.
- **L04 residuals:** Qualification covers integral signal default publication;
  derived Boolean contexts (L03),other value types and broader initialization
  obligations remain separate.


### L05 — Selected associative class-member foreach loses index type

- **Area / edition:** Foreach/arrays / IEEE1800-2017 and1800-2023 12.7.3.
- **State:** LOCALLY VALIDATED — reviewed selected-member index typing; remote CI before merge.
- **Evidence:** campaign-20260908/l01/typed.sv: values[string] member loop
  index becomes int and visits zero entries, also seen before L01.
- **Scope:** Exact implicit-index type resolution and necessary selected-member
  elaboration, preserving prefix selection and existing iteration behavior.
- **Closure:** Paired reducer, key/selection/lifetime controls, all required
  local gates and review; remote CI before merge.

- **L05 mechanism:** Preserve selected target paths through parser declarations
  and foreach index typing; reuse existing type-only lookup to reach the
  terminal array key type without evaluating selectors.
- **L05 validation:** Focus10/10 legacy+JSON, foreach neighbors53/34,
  makecheck/review, NFA58/58, integrated4765/4770 with zero unexpected failures,
  VPI105, negative149, runtime checks, fullJSON1662/0 and real-DPI UVM355/0/0 pass.
- **L05 residuals:** Invalid same-name header selectors (DD-009), selected-array
  non-member typing and broader container obligations are not qualified here.

### V04 — Merged type coverage saturates wide bin totals before division

- **Area / edition:** Coverage / IEEE1800-2017 and1800-2023 19.11.3.
- **State:** LOCALLY VALIDATED — reviewed merged aggregate arithmetic; remote CI before merge.
- **Evidence:** class_type::type_coverage narrows exact dynamic cardinality
  to UINT64_MAX and saturates per-item sums; instance coverage already uses
  unsaturated real aggregation. Multiple named wide families can exceed64 bits.
- **Scope:** Preserve supported merged totals through percentage calculation,
  retaining bin identity, thresholds, weights and mode dispatch.
- **Closure:** Paired relative-error reducer/controls, all required local gates
  and independent review; remote CI before separately authorized merge.
- **Residuals:** ParentV01, transition-family cardinality and cross-bin universe
  obligations remain separate. No per-blocker PR under updated cadence.

- **V04 candidate:** Local128-bit merged total/hit accumulation; individual
  transition-family cardinality unchanged. Focus2/2+2/2, coverage neighbors75/65,
  makecheck and independent review pass. Integrated4772total4767pass0fail2NI3EF,VPI105,negative149,runtime checks,
  fullJSON1664/0,UVM355/0/0,NFA58/58 all pass.

### V05 — Constructed cross bins are omitted or misidentified in merged type coverage

- **Area / edition:** Coverage / IEEE1800-2017 and1800-2023 19.6,19.11.3.
- **State:** LOCALLY VALIDATED — exact supported constructed-cross union/count scope; remote CI before merge.
- **Evidence:** campaign-20260908/v05/cross.sv: two dynamic cross instances,
  six-bin union and two hits; type coverage0 instead33.333333, instance25 correct.
- **Scope:** Register supported automatic cross-bin names/counts for merged
  type coverage and union already-resolved active named properties, preserving
  per-instance topology and full product identity.
- **Closure:** Paired canonical identity/union controls, required full gates
  and independent review; remote CI before merge. ParentV01 remains open.

- **V05 candidate evidence:** Ordered component-name tuples registered only
  after successful topology validation; local counts map to canonical type
  counters, with active named-property union. Focus13/13 legacy+JSON,
  coverage neighbors75/65,V04 neighbors2/2,NFA58/58 and independent review pass.
  Includes named/arrayed transition identities and malformed-plan denominator
  assertions. Integrated4785total4780pass0fail2NI3EF,VPI105,negative149,
  runtime checks,fullJSON1677/0,real-DPIUVM355/0/0 and makecheck all pass.
  ParentV01 remains open; unsupported topologies, transition cardinality and
  unqualified options are not closed. No immediate PR under milestone cadence.


### V06 — Merged item coverage uses instance weights instead of type weights

- **Area / edition:** Coverage / IEEE1800-2017 and1800-2023 19.7.1,19.11.3.
- **State:** LOCALLY VALIDATED — exact declaration-time item type-weight scope; remote CI before merge.
- **Evidence:** v06/type-weight.sv has coverpoint scores50/0,type weights3/1,
  instance weights1/3. Type returns12.5 rather than37.5; instance12.5 is correct.
- **Scope:** Declared coverpoint/cross type-weight validation, metadata and merged
  aggregation. Preserve independent defaults, instance modes and old bytecode.
- **Closure:** Paired semantic/invalid-value controls, scoped regression oracle
  corrections for item isolation, all required local gates and independent review.
  Procedural static assignment and other type-option obligations remain separate.

- **V06 evidence:** Typed constant validator handles independent defaults,
  zero weights, group noninheritance, static/dynamic/implicit crosses and
  merge0/instance isolation. Temporary typed aliases preserve constructor and
  sample scope, including legal type queries and outer constant functions.
  Old bytecode fallback and new tagged metadata bounds are controlled.
  Focus22/22+22/22,coverage75/65,V04 2/2,V05 13/13,integrated4807total4802pass
  zero unexpected2NI3EF,VPI105,negative149,runtime,JSON1699/0,UVM355/0/0,
  NFA58/58,makecheck and independent final review all pass. DD010 remains open.


### V07 — Never-instantiated covergroup types lower cumulative coverage

- **Area / edition:** Coverage / IEEE1800-2017 and1800-2023 19.9,19.11,19.11.3.
- **State:** LOCALLY VALIDATED — never-instantiated type eligibility only; remote CI before merge.
- **Evidence:** v07/uninstantiated-type.sv reports0 before any instance and50
  after constructing one fully covered type; expected100 in both situations.
- **Root:** Compilation registers types whose static metadata merge1 scores
  without checking whether an instance ever existed. Existing live registry
  and retired-options marker already preserve the required population state.
- **Scope:** Shared type-coverage eligibility, preserving constructed/retired
  populations and independent type/instance weights; no new metadata or registry.
- **Closure:** Paired lifecycle controls, full required local gates and review.
  Broader parentV01 and other coverage obligations remain open.

- **V07 validation:** Six permanent lifecycle entries pass both harnesses,
  with paired baseline failures and zero-weight/retirement controls. V04/V05/V06
  and coverage neighbors pass; integrated4813total4808pass0fail2NI3EF,VPI105,
  negative149,runtime,JSON1705/0,NFA58/58,UVM355/0/0 realDPI actual-g2012,
  makecheck and independent review pass. Existing live/retired state suffices;
  no metadata, ABI or scheduler changes. Broader qualification remains open.


### U02 — Published UVM revision compatibility matrix

- **Area:** UVM release compatibility / qualification tooling.
- **State:** LOCALLY VALIDATED — requested acquisition/probe tooling complete; release compatibility remains partial.
- **Evidence:** Accellera official downloads lists 1.0/1.1/1.2,2017 and2020 families; current U01 encounters a UVM-version boundary.
- **Scope:** Pin official sources, keep releases available locally, run isolated unmodified-library compile/smoke probes and record exact failures.
- **Closure:** Reproducible acquisition and honest per-release evidence. Does not require all versions to pass or establish IEEE1800.2/application qualification; discovered compiler gaps are record-only during U02.

- **U02 result:** 15 releases available;2020.2.0/2020.3.0/2020.3.1 compile and
  execute factory/copy/phase/regex/HDL smoke with zero warnings/errors/fatals.
  Twelve versions fail compilation; see `uvm_release_matrix.md`. Official Git
  releases use pinned submodules, others verified archive downloads. Six offline
  evidence-integrity/source-preservation controls pass. No compiler fix or
  broad UVM/application/ABI qualification is included in this tooling closure.


### L06 — Empty queues of structs with member defaults are rejected

- **Area / edition:** Data types / IEEE1800-2017 and1800-2023 7.10,7.2.2.
- **State:** CLOSED for empty queue-container initialization at `4965219df`; broader structure defaults remain open.
- **Evidence:** OfficialUVM2020.3.2 uvm_reg_map.svh2058 declares
  uvm_reg_bus_op accesses[$]; the element has data=0. Compiler emits an
  unsupported-default diagnostic for the queue declaration.
- **Expected:** An uninitialized queue is empty; no nonexistent element gets
  member initialization. Preserve valid scalar defaults and invalid-type errors.
- **Validation:** Fourteen paired legacy/JSON regressions, 27/26 neighbors,
  integrated 4827 total / 4822 pass / 0 unexpected failures / 2 NI / 3 EF,
  VPI 105, negative 149, runtime invariants, JSON 1719/0, NFA 58/58,
  real-DPI UVM 355/0/0, make check and independent review passed.
- **Release replay:** Unmodified UVM2020.3.2 passes the former declaration
  failure, then reaches the independently preexisting DD013 queue-last lvalue
  assertion. This is not a release/application pass. Unsupported array shapes
  and invalid member-default diagnostics remain explicitly covered.
- **Publication:** Local semantic qualification is complete. Separate B01
  Windows export correction and required remote merge gates remain pending.


### B01 — Windows coverage API import-library exports missing

- **Area:** Build/API ABI export map, no language-semantic change.
- **State:** CLOSED — old/new export invariant and review passed; required Windows CI now passed on PR273 head abcfdf7fb84b36b030ea8d28b05fca73ca06be16.
- **Evidence:** job102955775883 link of vvp.tgt reports seven missing coverage
  API symbols; all are declared in ivl_target.h and implemented in t-dll-api.cc.
- **Root:** Missing ivl.def entries prevent Windows import-library linkage.
- **Closure:** Old/new invariant proof, exact exports, independent review and
  required Windows CI. Update existing PR273; no new PR or agent merge.


- **Windows evidence:** UCRT64 job102981118128 completed success at2026-09-10T18:56:21Z, including build/link, regression, UVM and installed frontend. MINGW64 and CLANG64 also passed. Export map unchanged from reviewed7c779ff28; macOS remains queued for overall PR, no merge performed.


### U03 — Select a pinned UVM release from the iverilog command line

- **Area:** User-requested driver and release acquisition integration.
- **State:** CLOSED at `c35d2ef36` — focused, registration, selected real-DPI smoke, installed frontend, review, integrated and full JSON gates passed.
- **Authorization:** User requests a UVM version picker in iverilog similar to VCS.
- **Gap:** The driver accepts --uvm-home but has no release-ID selector or
  available-release listing. Existing --uvm-version reports the bundled version.
- **Contract:** Add --uvm=<release> and --uvm-list, using acquired pinned sources;
  preserve -uvm, --uvm-home and reporting-only --uvm-version behavior. Connect
  the downloader to discovery without downloading during a compiler invocation.
  Diagnose unknown/missing versions and conflicting path/version options clearly.
- **Validation:** Driver parsing/resolution tests for valid, missing, invalid and
  conflicting selectors; listing; path with spaces; existing-option controls;
  real-DPI compile/run smoke using a known passing pinned release. Required
  repository gates and independent review remain in force. Selecting a release
  does not qualify its language support or turn current compile failures into passes.
- **Boundary:** B01 is safely suspended awaiting external Windows CI; U03 is
  independent of the export-map correction. L06 passed all local gates before
  installing the candidate driver. U03 is the sole active implementation task.

- **Final validation:** Integrated 4827 total / 4822 pass / 0 unexpected
  failures / 2 NI / 3 EF; VPI105, negative149, runtime15/15; JSON1719/0.
  Availability is separate from compatibility and IEEE1800.2 qualification.

### L07 — Queue-last element assignment aborts elaboration

- **Area / editions:** Queue lvalues, IEEE1800-2017 and IEEE1800-2023 7.10/7.10.1.
- **State:** CLOSED at `9a1b6beb3` for direct queue-variable element lvalues; class-member and other parent forms remain unqualified.
- **Evidence:** Unmodified UVM2020.3.2 uvm_field_op.svh112 assigns msg_queue[$].
  Minimal string queue assignment aborts both saved baseline and L06 candidate.
- **Root candidate:** Plain queue lvalue dispatch handles SEL_BIT but omits
  SEL_BIT_LAST and reaches the SEL_NONE assertion. Trace all related consumers
  before correcting the shared lowering path.
- **Scope:** Runtime last-element selection for direct queue variables and
  affected ordinary element assignment paths; retain empty/bounded queue,
  element-type, index evaluation and existing member-selection semantics.
  Any unsupported parent shapes remain explicitly scoped and recorded.
- **Closure:** Standards evidence, baseline red, permanent paired regressions,
  smallest causal patch, required integrated validation and official release
  replay. Removing the assertion alone is not implementation.

- **Final evidence:** Baseline aborts in both editions. Ten paired legacy/JSON
  tests, neighbors21/13, make check, independent review, integrated4837 total
  with zero unexpected failures, VPI105, negative149, runtime15/15, JSON1729/0,
  NFA58/58 and real-DPI UVM355/0/0 pass. Full 15-release replay is complete and
  baseline-valid: four smoke passes, eleven compile failures. No broad queue,
  UVM, application or formal-program completion claim is made.

### P04 — Process kill misses descendants in synchronous task frames

- **Area / edition:** Process runtime / IEEE1800-2017 and2023 9.7.
- **State:** CLOSED for live-parent descendant traversal; locally validated at `53b58890c63a48aa1943c7ef065db59f19cebef3`.
- **Evidence:** `u01-after-l07/kill_task_children.sv`; both edition runs report
  parent KILLED, child WAITING, counter continuing4to9 after parent.kill.
- **Cause:** Descendant kill traversal skips joined synchronous task frames;
  their live detached children are later reparented during frame cleanup.
- **Scope:** Live-parent kill through synchronous frames only. Terminal-parent
  kill DD-014 and application teardown qualification remain separate.
- **Closure:** Permanent task/frame/deep-descendant and sibling controls;
  focused and required integrated gates, independent review, then U01 replay.

- **P04 validation:** Six paired regressions and all required focused/integrated gates passed: legacy4843total0unexpected failures,JSON1735/0,real-DPIUVM355/0/0,NFA58/58,VPI105,negative149,runtime15/15,makecheck and independent review. U01 replay remains separate.

### L08 — UVM2020.1 resource-queue typing frontier

- **Area / edition:** Class-scoped type actuals, IEEE1800-2017/2023 6.20.3 and8.23.
- **State:** CLOSED for class-scoped type actual resolution and specialization identity; release-wide qualification remains open.
- **Evidence:** DD-011; original2020.1.0/1.1 compile logs in the pinned release
  matrix stop at nested resource-queue type/assignment errors.
- **Closure:** First causal reducer, applicable IEEE semantics and minimal
  implementation scope before any patch; permanent regression, required gates
  and review. No release-wide or application qualification by implication.

- **L08 candidate evidence:** Scoped resource-queue actual fails in both editions on the validated baseline; explicit equivalent type passes. Type-only class-member lookup and resolved specialization keys now pass ten permanent paired regressions in legacy and JSON runners, related17/15 controls and make check. Independent review clear after preserving dotted-path provenance through SVA cloning. Integrated legacy/VPI/negative/runtime, full JSON, real-DPI UVM and NFA remain required; no closure yet.

- **L08 closure:** Implementation47e6c87b3 passed all required local gates: legacy4853total4848pass0fail2NI3EF,VPI105,negative149,runtime15/15,JSON1745/0,NFA58/58,real-DPIUVM355/0/0,focused10/10each,neighbors17/15,makecheck and independent review. Original2020.1.0/1.1 compile but fail runtime as separately recorded in DD-011.

### U04 — Original UVM2020.1 DPI regex loading

- **State:** CLOSED at aa172f5f9 for legacy regex C ABI and real error propagation; original release phase qualification remains DD-017.
- **Evidence:** DD-011, results-gizcr5j0; both original releases compile but miss uvm_re_match/uvm_glob_to_re symbols at runtime, followed by BUILDERR.
- **Scope:** Establish declarations, loaded exports and causal reducer before authorizing a bounded patch. No library edits or release-wide qualification.

### U05 — Standalone DPI reporting callback

- **State:** CLOSED at a5eb76ebb after all required local validation; resume U04.
- **Evidence:** u04/report_bridge.sv compiles but callback count remains0; standalone umbrella defines exported report callback as no-op.
- **Scope:** Existing runtime export dispatcher adapter, preserved merged builds, argument/count and real-UVM reporting tests. U04 legacy regex reducers preserved; resume after validation.

- **U05 closure evidence:** Four paired baseline failures become four passes in relocated frontend S10; S1-S10,review,makecheck,NFA58/58,integrated4853total0unexpected,VPI105,negative149,runtime15/15,JSON1745/0,real-DPIUVM355/0/0 passed. No legacy regex compatibility claim from this reporting fix.

- **U04 closure:** All required local gates passed: paired ABI/error controls,original2020.1.0/1.1 ABI4/4,relocated frontendS1-S10,review,makecheck,NFA58/58,legacy4853total0unexpected,VPI105,negative149,runtime15/15,JSON1745/0,real-DPIUVM355/0/0. Full15release matrix remains4SMOKE_PASS,9COMPILE_FAIL,2RUNTIME_FAIL; no release-wide qualification inferred.

### U06 — Original UVM2020.1 phase execution

- **State:** CLOSED at aad6fe22b (semantic patch fe4e949b8), after all required gates.
- **Evidence:** Both original releases finish at time0 without the smoke marker or expected missing-traffic fatal, despite successful direct ABI checks.
- **Resolved scope:** Preserve recursive caller input context across nested argument calls; IEEE2017/2023 8.6 and13.5.1. Original sources unchanged; both2020.1 releases now execute intended smoke checks through time1.
- **Validation:** legacy4855/0,VPI105,negative149,runtime15/15,JSON1747/0,real-DPIUVM355/0/0,NFA58/58,makecheck,independent review,relocated frontendS1-S10. Paired reducer fails baseline/passes candidate in both editions. Full15release matrix6SMOKE_PASS9COMPILE_FAIL; original2020.1 smoke4/4 in2017/2023. DD018 output-copying scope was subsequently resolved by L09.

### L09 — Nested argument output copy-out loses caller automatic destination

- **State:** CLOSED at 3c44fd13b after all required local gates.
- **Evidence:** Preserved nested output control fails identically before/after U06; caller local remains unchanged.
- **Scope:** Explicit automatic copy-out phases select callee formal loads and caller destination reads/writes, preserving frame ownership and existing typed copying. IEEE2017/2023 8.6 and13.5.
- **Evidence at candidate:** Three permanent regression families fail baseline and pass both editions; focused JSON38/0, malformed bytecode6/6, NFA58/58, makecheck and independent review pass. Full legacy4861/0,JSON1753/0,real-DPIUVM355/0/0,VPI105,negative149,runtime15/15 and frontendS1-S10 passed; restored tools match frozen fingerprints. Class fixed-array property scalar output (DD019) was resolved separately by L10.


### L10 — Fixed-array class-property element output copy-out

- **State:** CLOSED at 051aeee8e after validated prerequisite L11 and all required local gates.
- **Evidence:** Legal scalar output actual holder.slots[index] emits a skipping warning and remains unchanged.
- **Scope:** Existing fixed property slot checks and typed property stores; preserve receiver/index context and invalid-index semantics. No unrelated container expansion.

- **L10 validation:** legacy4873total0unexpected,VPI105,negative149,runtime15/15,copyout6/6,JSON1765/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON50/0,focusedlegacy8/0,independent review,frontendS1-S10; restored root and unchanged frozen fingerprints. Fixed property elements only; broader output/array support remains separately scoped.

### L11 — Scalar output actuals must not be copied in

- **State:** CLOSED at b32df9a29 after all required local gates.
- **Scope:** Native output argument setup must skip caller reads, initialize automatic formals to defaults, retain static formals and preserve DPI open-array handling.

- **L11 validation:** legacy4865total0unexpected,VPI105,negative149,runtime15/15,copyout6/6,JSON1757/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focused42/0,independent review,frontendS1-S10; root restored and frozen hashes unchanged.


### U07 — Legacy UVM member delay compatibility

- **State:** CLOSED at a83731194 after all required local gates.
- **Evidence:** Original1.2 #setting.offset fails parsing; same first frontier in older releases.
- **Classification:** Nonstandard unparenthesized member delay; both IEEE editions require parentheses. Use existing miscellaneous extension switch, preserving strict rejection and normal delay semantics; no library patches.

- **U07 validation:** legacy4881total4876pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,JSON1773/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON8/0,legacy8/0,delayneighbors40/0,independent review,frontendS1-S10; installed root restored and frozen hashes unchanged. Eight release smoke passes; six compile gaps and one runtime timeout remain. This closes only compatibility syntax under the existing miscellaneous-extension mode, not IEEE/UVM parent qualification.

### L12 — String character reads through unpacked struct members

- **State:** CLOSED at a85a256b1 after all required gates.
- **Evidence:** DD021 original UVM1.2 printer row.val[0] receives explicit unsupported struct-member index diagnostic.
- **Scope:** Correct bounded rvalue string indexing, preserving byte type, bounds and index evaluation. Static-local references and constraints remain separate blockers.

### L13 — Signed byte semantics of string character reads

- **State:** CLOSED at849a779ea after corrected index conversion and all required gates.
- **Evidence:** Ordinary s[0] with octal377 yields255 when widened, while getc and byte cast yield-1. Both editions6.16/6.16.3/6.11.3 specify signed byte semantics.
- **Scope:** Shared character-select typing and expression sizing, preserving unsigned packed bit/part selects.

- **L13 validation:** legacy4887total4882pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,JSON1779/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON6/0,legacy6/0,stringneighbors42/0,independent review,frontendS1-S10; installed root restored and frozen hashes unchanged. Fullrelease results-6pvdp6vh retain8smokepasses,6compilegaps,1timeout; normalized diagnostics and source hashes match U07. General class-property dispatch and constant-function string evaluation remain open.

- **L13 corrected validation:** 849a779ea; legacy4887total4882pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,JSON1779/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON6/0,legacy6/0,neighbors42/0,independent review,frontendS1-S10; root restored and frozen hashes unchanged. Release results-m_3ysaa5 retains8passes6compilefail1timeout with matching row sources and normalized diagnostics.

- **L12 validation:** a85a256b1;legacy4893total4888pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,JSON1785/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON6/0,legacy6/0,neighbors71/0,independent review,frontendS1-S10; root restored and frozen hashes unchanged. Original release sweep results-qb7873zh:8SMOKE_PASS5COMPILE_FAIL1RUNTIME_FAIL1RUNTIME_TIMEOUT. Full UVM release and application qualification remain open.

### L14 — Static local hierarchical references inside automatic scopes

- **State:** CLOSED at69ff60cc6 after all required gates.
- **Evidence:** Original1.2 visit.compiled_regex read/write rejected as automatic despite explicit static chandle declaration.
- **Semantics:** Both IEEE editions6.21 explicitly permit static-variable hierarchical references inside automatic tasks/functions, except unnamed blocks. Preserve automatic-variable rejection.

- **L14 validation:** 69ff60cc6;legacy4905total4900pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,JSON1797/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON12/0,legacy12/0,neighbors18/0,independent review,frontendS1-S10; root restored and frozen hashes unchanged. Release results-f9qr050b:8SMOKE_PASS4COMPILE_FAIL1RUNTIME_FAIL2RUNTIME_TIMEOUT; all15 source hashes unchanged, other14 normalized compile logs identical. UVM1.2 runtime timeout remains DD028.

### U08 — Inherited-method lookup causes UVM1.2 root recursion

- **State:** CLOSED at c9626a449 after all required local gates.
- **Evidence:** DD028, original1.2 compiles then times out300s with no runtime output.
- **Resolved scope:** Inherited unqualified method precedence over enclosing homonyms; receiver/task/virtual binding, local visibility and static-caller diagnostics covered under both editions. General access control remains DD029; original1.2 still fails legacy regex DPI (DD030).

- **U08 validation:** c9626a449;legacy4911total4906pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,JSON1803/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON6/0,legacy6/0,neighbors32/0,independent review and external-review reconciliation,frontendS1-S10; root restored and frozen hashes unchanged. Release results-eb3ghca7:9SMOKE_PASS4COMPILE_FAIL2RUNTIME_FAIL; no source changes.2017.0.9 now passes;1.2 reaches regex DPI errors.

### U09 — Legacy UVM regex DPI entry points

- **State:** CLOSED at19e7f5592 after all required local gates.
- **Evidence:** DD030/DD027, original1.2 and1.1d import uvm_dpi_regcomp/regexec/regfree; installed modern umbrella exports none of those names. Pinned legacy sources already contain the implementation.
- **Scope:** Provide the legacy C ABI on the Icarus backend with strict regex semantics, error reporting and handle lifetime; permanent coverage and original-release replay. No library-source edits or full application claim.


- **U09 validation:** Focused10/10 under2017/2023; legacy4911total4906pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,JSON1803/0,real-DPIUVM355/0/0,NFA58/58,makecheck,independent review and frontendS1–S10. Installed root restored and frozen hashes unchanged. Original15release sweep results-n2m35ki0:11SMOKE_PASS4COMPILE_FAIL; all source hashes unchanged. Exact cached-regex gap closed, full release/application qualification remains open.

### U10 — OpenTitan UVM1.2 selection and provenance

- **State:** CLOSED at aaf8df44c for source selection/provenance; application qualification remains open.
- **Gap:** Replay harness selects and fingerprints bundled UVM despite pinned OpenTitan commercial configurations selecting1.2.
- **Scope:** Forward an explicit acquired source root, record its actual fingerprint and replay the pinned debug crossbar with original1.2. Keep all application checking and failure criteria.

- **U10 validation:** aaf8df44c harness only, compiler19e7f5592 unchanged. Permanent self-test PASS, invalid path exit2, explicit root/src/environment/override normalization4/4, independent review clear, diff/YAML checks pass. Pinned OpenTitan7a3ad34 original1.2 replay records correct source hash885ba9f74652494aa132aaaa26c43e9f210f94cdf5a8d3a87064993ec9b35dc0 and fails compile74 at legacy macro expansion; zero application traffic, no pass claim. DD031 preserves next frontier.

### L15 — Pasted function-like macro names with numeric suffix

- **State:** CLOSED at aa356ab4d after required local validation and original1.2 replay.
- **Evidence:** DD031 original1.2 OpenTitan field macro pastes uvm_print_aa_string_int3 but reports a missing argument list for its shorter prefix.
- **Scope:** Prove text-substitution semantics, correct the causal preprocessor boundary and preserve permanent paired-edition regression. No upstream source modifications.

- **L15 validation:** aa356ab4d; macrofocuslegacy24/0,JSON6/0,independent review,makecheck,legacy4913total4908pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1805/0,real-DPIUVM355/0/0,NFA58/58,frontendS1-S10; installed root restored and frozen hashes unchanged. Full15release11SMOKE_PASS4COMPILE_FAIL; all statuses/source hashes unchanged. OpenTitan macro errors/cascades removed; next failure is three const-handle member assignment diagnostics, DD032. No application pass.

### L16 — Mutable property through a const class-handle variable

- **State:** CLOSED at5ba60567f after required local validation and original1.2 replay.
- **Evidence:** DD032, original1.2 OpenTitan rejects uvm_top.enable_print_topology assignment.
- **Scope:** Both-edition6.20.6 direct const-handle variable member writes, retaining handle/const-property/value-aggregate protection. No complete const qualification claim.

- **L16 validation:** 5ba60567f; focusedlegacy8/0,JSON8/0,neighborslegacy18/0,JSON32/0,independent reviews,makecheck,legacy4921total4916pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1813/0,real-DPIUVM355/0/0,NFA58/58,frontendS1-S10; root restored and frozen hashes unchanged. Full15release11SMOKE_PASS4COMPILE_FAIL; all statuses/source hashes unchanged. Original1.2 OpenTitan replay42522: compiler0/runtime0,9.964s,152requests/288scoreboard items,0UVMwarnings/errors/fatals,TEST PASSED CHECKS and normal finish17625626ps. OverallDEBT from five compile-time null-fallback diagnostics on compound array-member operations; no application qualification. No waived checks/source edits.

### L17 — Integral compound updates of dynamic-array properties

- **State:** CLOSED at d8e974913 after all required local gates and original1.2 application replay.
- **Evidence:** DD035, five original1.2 register-item array updates emit null fallbacks.
- **Scope:** Typed integral element compound updates with single index evaluation, receiver/width preservation and invalid-index no-write behavior. No full compound/container qualification claim.

### L18 — Resolved property signedness in compound assignment

- **Status:** CLOSED at9791e6411; signedness prerequisite for suspended L17.
- **Evidence:** Signed scalar class property -64 /= 2 produces2147483616, expected-32. NetAssign_ signed_ is default-false for property shapes.
- **Scope:** Use resolved integral selected type in compressed-assignment elaboration. Paired signed/unsigned/part-select regressions and all required gates. No dynamic-array compound qualification before L17 resumes.

L17 coordination boundary: suspended with full partial patch/tests at
`evidence/campaign-20260908/l17/partial.patch`. Focus exposed prerequisite
operand width/state loss and signedness loss before target lowering. L18
handles signedness; DD036 preserves width/state debt. No L17 closure.

L18 closure: focused paired-edition/neighbor tests, independent review and all
required local gates pass; original15release statuses unchanged. Only direct
integral property signedness is resolved. DD036 width/state preservation and
L17 dynamic-array lowering remain open.

### L19 — Preserve four-state compound operands

- **Status:** CLOSED at72a97c038; state-conversion prerequisite for suspended L17.
- **Evidence:** On validated9791e6411, bit[7:0] value=1;value+=logic X yields1 in both editions; expected0 after unknown arithmetic result is assigned to bit.
- **Scope:** Delay destination two-state conversion until after the integral compound operator. Width preservation remains separate DD036 work. All required gates apply.

L19 closure: paired four-state operand and two-state result checks, signedness/
concatenation neighbors, independent review and all required local gates pass.
DD036 operand width and L17 target lowering remain open.

### L20 — Integral compound operation widths

- **Status:** CLOSED atfe12166bd; compressed-vector width prerequisite for suspended L17.
- **Evidence:** On validated72a97c038, logic8bit128 /=32'd256 producesX instead0 in both editions. L17 also demonstrates wide shift count truncation.
- **Scope:** Natural/context RHS width through compressed elaboration and shared vector operation sizing before final result truncation. Preserve existing receiver/index lowering; no new runtime instructions. All required gates apply.

L20 closure: paired constant/runtime widths, signedness/context, self-determined
shift counts, property parts and array/queue cases pass with all required
local gates. Associative front-end expansion remains residual DD036 debt; no
complete associative or parent compound qualification. L17 can now resume.

L17 resumes after validated L18/L19/L20 onfe12166bd. Original red/partial patch
are preserved; adapt append-only manifests and reuse the validated width helper.
All L17 gates/application replay remain required before exact-scope closure.

### L21 — Captured class-root notification preserves rebound handles

- **Status:** CLOSED at1146d2187; captured class-root runtime prerequisite for resuspended L17.
- **Evidence:** Standalone scalar h.value+=rebind() mutates original but restores old h during notification. Captured root delivery overwrites RHS reassignment.
- **Scope:** Guard captured class-root delivery with live binding identity while preserving alias/property events and contexts. All required gates apply. L17 resumed patch is preserved as partial-after-l20.patch.

L21 closure: replacement/null rebind, retained-alias/property events, unchanged
root and automatic-context controls pass with all required local gates. Guard
is limited to captured non-struct class roots; value aggregates/VIF remain
unchanged. L17 can resume on the validated runtime.

L17 closure after validated L18/L19/L20/L21 prerequisites: d8e974913;focuslegacy2/0,JSON2/0,neighborslegacy24/0,JSON23/0,original red passes both editions,makecheck,independent source review;legacy4931total4926pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1823/0,realDPIUVM355/0/0,NFA58/58,frontend97109exit0 all scenarios;install restored and five frozen hashes match. Complete15release results-3d_bbaiu11SMOKE_PASS4COMPILE_FAIL;all15 statuses/source/archive hashes match L21.

Original1.2 OpenTitan debug-crossbar replay6645: PASS,compiler0/runtime0,10.177s,152hostrequests/288scoreboarditems,0UVMwarnings/errors/fatals,compile semantic debt0/runtime debt0,TEST PASSED CHECKS and normal finish17625626ps. Original corpus7a3ad34 clean;UVMsrcSHA885ba9f74652494aa132aaaa26c43e9f210f94cdf5a8d3a87064993ec9b35dc0 unchanged. Actual -g2012,one default-seed smoke invocation;no paired-edition/multi-seed/full OpenTitan qualification. Two existing benign runtime lines report discarded $system return value.

### L22 — Built-in process::state nominal enum type

- **State:** CLOSED at4a102ee47 after all required gates.
- **Evidence:** Original UVM1.0p1 uvm_phases.svh2824 function return type fails visible-class lookup on d8e974913.
- **Scope:** 2017/2023 9.7 declared state enum and typed status/constants, preserving 6.19 nominal enum semantics. No scheduling redesign or full UVM1.0p1 qualification.

L22 validation: 4a102ee47;focuslegacy6/0,JSON6/0,neighborslegacy16/0,JSON10/0,makecheck and final independent review;Bison563SR1122RR,parse.output identical;legacy4937total4932pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1829/0,realDPIUVM355/0/0,NFA58/58,frontend18561exit0 all scenarios;install restored and five frozen hashes match. Complete15release results-p7axbpcu11SMOKE_PASS4COMPILE_FAIL;all15 source/archive hashes and statuses match L17,1.0p1 process::state error removed.

Bare class-scoped module declarations remain DD039; no full process or UVM1.0p1 qualification. Next exposed nested-background fork error is DD040.

### L23 — Nested joins in function-spawned background processes

- **State:** CLOSED at58edf8034 after required validation.
- **Evidence:** DD040 and both-edition reducer reject join_any within outer function fork/join_none.
- **Scope:** 13.4.4 task-legal background children using existing isolated elaboration context; retain direct function blocking-join errors. No scheduling/lifetime redesign or full UVM qualification.

L23 validation: 58edf8034;originalred both editions PASSED/no diagnostics,focuslegacy4/0,JSON4/0,existingfunctionfork2/0 both,neighborslegacy43/0,JSON33/0,makecheck and final independent review;legacy4941total4936pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1833/0,realDPIUVM355/0/0,NFA58/58,frontend38601exit0 all scenarios;install restored and five frozen hashes match. Complete15release results-2hbuhcyt11SMOKE_PASS4COMPILE_FAIL;all15 statuses/source/archive hashes match L22. Nested-fork diagnostic removed from1.0p1/1.1a;each retains three void-cast-of-void errors.

### L24 — Void function calls in void-cast statements

- **State:** CLOSED at795d9f360 with test reconciliation8afc61443 after required validation.
- **Evidence:** DD041, both-edition calls with argument/output effects rejected; original1.0p1/1.1a each fail three such calls.
- **Scope:** Dedicated13.5/A.6.9 function-call statement grammar, preserving actual effects and task/void-expression/deferred-action restrictions. The grammar/prose reading is explicitly recorded as inference; no compatibility bypass or upstream source edits.

L24 validation reconciliation: the initial integrated run found the legacy-only
`sv_void_cast_fail1` expected the dedicated statement to be rejected. That obsolete
expectation is replaced by direct void-function expression rejection; the new
paired tests own legal-statement coverage. Independent review agrees. This does
not qualify historical2005 acceptance. Required rerun remains pending.

L24 final validation: 795d9f360 with test reconciliation8afc61443;originalred both editions PASSED,no diagnostics;focuslegacy7/0,JSON4/0,neighbors23/0 both,makecheck,independent review;legacy4945total4940pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1837/0,realDPIUVM355/0/0,NFA58/58,frontend93910exit0 all scenarios;install restored and five frozen hashes match. Complete15release results-6_pvcxya11SMOKE_PASS2COMPILE_FAIL2RUNTIME_FAIL;all15 source/archive hashes match L23. 1.0p1/1.1a now compile/start but missing older DPI prevents pass;1.0p1 also unresolved-functor/cast diagnostics.

### U11 — Original UVM1.0p1/1.1a DPI entry points

- **State:** CLOSED at e18128369 after required validation.
- **Evidence:** DD042 missing old command-line/regex symbols in unmodified sources.
- **Scope:** Real argv iteration/restart and metadata, strict cached regex adapters;
  no original-source edits or unrelated legacy runtime/recording fixes.

U11 final validation: e18128369;both-edition red failed missing old DPI entrypoint;focused8/0,makecheck,independent code/evidence review;legacy4945total4940pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1837/0,realDPIUVM355/0/0,NFA58/58,frontend41504exit0 all scenarios including oldABI both editions;install restored and five frozen hashes match. Release results-zyhh1jv9 complete/baseline_valid,all15source/archive hashes unchanged. Reviewed12clean smoke passes,1disqualified1.0p1 runtime,2compilefails;raw1.0p1SMOKE_PASS rejected due existing3placeholder and2cast diagnostics. 1.1a clean new smoke pass through time1.

### U12 — Simulator diagnostics cannot be clean release smoke passes

- **State:** CLOSED at1654dc4c9 after required harness validation.
- **Evidence:** DD043 original1.0p1 false-positive runtime row.
- **Scope:** Existing shared classifier/offline tests and fresh release evidence;
  no compiler changes or repair of underlying runtime diagnostics.

U12 final validation: 1654dc4c9;newdiagnosticnegative failed8subcases beforefix,all8offline matrix tests pass;all13historical runtime logs correct12accept/1reject;independent review caught/fixed quoted-UVM_INFO falsepositive with permanent control. Fresh15release results-fm8uvyiv complete/baseline_valid,12SMOKE_PASS1RUNTIME_FAIL2COMPILE_FAIL;all15source/archive and alltoolhashes unchanged vsU11. Only1.0p1 rawstatus corrected;no compiler/DPI or IEEE semantic gain. Frozen U11 fivehashes match.

### L25 — Integral function-name variable passed by reference

- **State:** CLOSED atc58035f49 after requiredvalidation.
- **Evidence:** Both-edition7-to12 ref-update reducer fails; three original1.0p1
  build_coverage functions bind a ref formal to an omitted return signal.
- **Scope:** True reference storage under13.4.1/13.5.2, retaining return and
  lifetime semantics. Address-taken return variables use existing signal/context storage.
  Callback cast/typeidentity diagnostics remain separate.

L25 final validation: c58035f49;originalred/interactions both editions PASSED,no diagnostics;focuslegacy2/0,JSON2/0,neighborslegacy58/0,JSON46/0,makecheck and independent design/code review;legacy4947total4942pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1839/0,realDPIUVM355/0/0,NFA58/58,frontend88452exit0 allscenarios;installrestored and fivefrozenhashesmatch. Complete15release results-3v03d7qs12SMOKE_PASS1RUNTIME_FAIL2COMPILE_FAIL;all15statuses/source/archivehashes unchanged vsU12. Original1.0p1 threeplaceholder diagnostics gone;two callbackcast errors remain.

### L26 — Matching class parameters with independent defaults

- **State:** CLOSED at e3666fd07 after required validation.
- **Semantics:** Both IEEE editions 8.25 require matching effective class-type
  parameters of the same generic declaration to select one type.
- **Cause:** Existing canonical key path requires a dependent default, so
  independent omitted/explicit defaults incorrectly retain source identity.
- **Scope:** Concrete multi-class-type parameters with bare nominal class defaults; preserve unresolved
  forwarding and owner identity. Generic-template initialization remains separate.
- **Evidence:** `evidence/campaign-20260908/l26/default-pair.sv` and `.json`;
  larger original-callback reducer and passing controls retained.

L26 final validation: e3666fd07; both-edition15line reducer PASSED; focuslegacy2/0,JSON2/0,paramneighbors23legacy/16JSON,identity/dependent/seedneighbors6/0each,makecheck and independent design/code review; legacy4949total4944pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1841/0,realDPIUVM355/0/0,NFA58/58,frontend29502exit0 allscenarios; installation restored and five sha256-final hashes match. Complete15release results-8054igtp12SMOKE_PASS1RUNTIME_FAIL2COMPILE_FAIL; all15statuses/source/archivehashes matchL25, original1.0p1 stilltwo callbackcasts.

### L27 — Generic master static initialization

- **State:** CLOSED at8f2252dd3 after required validation.
- **Semantics:** Both8.25 assign static storage to concrete specializations;
  the generic class itself is not a type.
- **Cause:** `netclass_t::elaborate` emits a static initializer process even
  for the unspecialized generic master. One requested specialization causes
  two registration side effects.
- **Scope:** Generic masters only; preserve actual concrete/default and ordinary
  class initialization. Seed-derived forwarding lifecycle remains DD044.
- **Evidence:** `evidence/campaign-20260908/l27/seed-init.sv` and `.json`.

L27 final validation: 8f2252dd3; both-edition red PASSED; focuslegacy2/0,JSON2/0,static/identityneighbors37legacy/25JSON,makecheck and independent design/code review; legacy4951total4946pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1843/0,realDPIUVM355/0/0,NFA58/58,frontend78203exit0 allscenarios; installation restored and five frozen hashes match. Complete15release results-ni3wgjii12SMOKE_PASS1RUNTIME_FAIL2COMPILE_FAIL;all15statuses/source/archivehashes matchL26;original1.0p1 stilltwo callbackcasts.

### U13 — Literal legacy DPI arguments versus GNU runtime options

- **State:** CLOSED, exact harness scope on9006baa15. Prior published2785
  Linux CI failed before simulation with `vvp: invalid option -- f`.
- **Cause:** The fixture invocation lacks `--` before the program/argv.
  `vvp/main.cc` deliberately allows GNU getopt permutation.
- **Scope:** Invocation separator only; retain literal `-f` iteration assertions,
  metadata/regex behavior, and all diagnostics. Local frontend and fresh Linux
  CI are required; no compiler/DPI semantic change.

U13 validation complete: local isolated frontend35171exit0 with all original
argv/regex checks retained and installed hashes restored. Fresh published
9006baa15 jobs103200770181 (Ubuntu22.04) and103200770250 (Ubuntu24.04)
both succeeded; logs confirm legacy_10_dpi IEEE2017 and2023 PASS on both.
Evidence: `evidence/campaign-20260908/l29/ubuntu2204.plain.log` and
`ubuntu2404.plain.log`. Independent review clear. Other PR275 platform
checks remain pending; this closure is not PR readiness or merge permission.

### L28 — Unresolved forwarded type initializer side effects

- **State:** CLOSED at77cce610b after required local validation.
- **Cause:** Symbolic forwarding requests have specialized-instance metadata
  while their actual retains generic source lineage; static init ignores this.
- **Scope:** Existing deferred-type predicate at process registration; preserve
  concrete cache reuse, initialization analysis and ordering. DD044 evidence.
- **Coordination:** U13 remains awaiting fresh Linux CI on9006baa15; it only
  changes a fixture command. L28 has no dependency on that pending harness gate.

L28 final validation: 77cce610b; counter and callback reds both editions PASSED/no diagnostics; focuslegacy4/0,JSON4/0,static/identityneighbors37legacy/25JSON,L27neighbors2/0each,makecheck and independent design/code/evidence review; legacy4955total4950pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1847/0,realDPIUVM355/0/0,NFA58/58,frontend91254exit0 allscenarios;installation restored/five frozen hashes match. Complete15release results-edrgslxb13SMOKE_PASS2COMPILE_FAIL;only1.0p1 statusimproves,all15source/archivehashes unchanged. Original1.0p1 cleanruntime/time1 with zeroUVMwarnings/errors/fatals;existingcompileconstraint/castlimitations remain,notfullUVMqualification.

### L29 — Abandoned procedural block scope during parser recovery

- **Status:** CLOSED at9229c24e7, bounded procedural-block recovery; robustness only.
- **Evidence:** `evidence/campaign-20260908/l29/one-loop.sv`, both editions
  abort134 on validated77cce610b; legal replacement compiles0. Existing parser
  trace shows a discarded begin midrule leaves lexical scope active, then
  normal enclosing for reduction reaches a scope assertion.
- **Scope:** Release discarded procedural block scopes at their ownership
  boundary; retain syntax rejection and valid nested/named/loop behavior.
- **Not claimed:** Recording support, another UVM release pass, or all parser
  recovery. Foreach carrier recovery remains DD045. U13 Linux CI has passed.

L29 final validation: 9229c24e7; original malformed reducer and all five procedural block forms reject normally in both editions; paired runtime lifetime/label/foreach/fork controls PASS. Focus12legacy/12JSON,neighbors68legacy/57JSON,makecheck and independent design/code/test reviews clear. Bison563SR1122RR unchanged. Legacy4967total4962pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1859/0,realDPIUVM355/0/0,NFA58/58,frontend74117exit0 allscenarios;installation restored/five frozen hashes match. Complete15release results-bwek89ja13SMOKE_PASS2COMPILE_FAIL;all status/source/archivehashes unchanged vsL28. 1.1b/c now normalcompile32 without assertion,not new UVM passes.

### L30 — Direct class-scoped type declarations at module scope

- **Status:** CLOSED at34787868e; bounded DD039 direct complete-class type route.
- **Reducer:** Complete class holder with typedef int state; module declares
  holder::state s. Both editions reject as invalid module instantiation.
- **Scope:** Reuse class type resolution at the module declaration frontier;
  preserve type identity, variable shapes and illegal-prefix/access rejection.
- **Authority:** Both editions6.18/8.23; unresolved prefix restrictions remain.
- **Evidence:** `evidence/campaign-20260908/l30/`; no fullclass/UVM claim.

L30 final validation: 34787868e; originalredcompile0/no diagnostics both editions; permanentfocus12legacy/12JSON,neighbors43legacy/32JSON,makecheck and independentdesign/code/ownershipreviewclear. Bison563SR1122RRunchanged. Legacy4979total4974pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1871/0,realDPIUVM355/0/0,NFA58/58,frontend21313exit0 allscenarios;installation restored/fivefrozenhashes match. Complete15release results-jz6zk_cb13SMOKE_PASS2COMPILE_FAIL;allstatuses/source/archivehashes unchanged vsL29. No fullclass/UVM qualification claim.

### L31 — Associative compound expression typing

- **Status:** CLOSED at0a4e7d639; bounded DD036 associative expression typing.
- **Reducer:** Signed byte associative element -64/=2 gives96 instead of-32
  in both editions. Expansion emits unsigned division.
- **Scope:** Resolved element signedness and binary operand width/state through
  final store; mixed unsigned and self-determined shift controls required.
- **Authority:** Both editions11.4.1/11.6/11.8; evidence l31.

### Campaign priority — Eliminate remaining behavior-changing compile-progress paths

User-directed follow-on after the UVM smoke campaign: implement and qualify
correct semantics for every remaining compile-progress stub or fallback that
emits incorrect behavior. This includes silent degradation, not only diagnostics.
An unsupported error, removed warning, or smoke pass does not close a legal
feature. Select one concrete blocker at a time using reducers and applicable
IEEE semantics; existing registries are not an exhaustive inventory.

Confirmed initial evidence is original1.0p1 `results-jz6zk_cb/compile.log`
(per-release `1.0p1/compile.log`): ignored `pick_sequence` constraint at
uvm_sequence_base.svh949, and class-cast bits reinterpretation at
uvm_phases.svh1951. Reproduce exact semantic effects before selecting each
implementation contract. A constant-loop warning alone is not a stub.
L31 remains active; this priority does not authorize unrelated edits in its patch.


User follow-up explicitly authorizes a sweep of **all fallbacks**, including
silent paths and qualification-harness substitutions. DD046 records the first
tracked-source inventory, source-confirmed categories, false-positive rules,
and remaining semantic triage. This is discovery work, not another governance
bootstrap. Fix behavior-changing cases after UVM smoke, with one active blocker.

L31 final validation: 0a4e7d639; both-edition signed/mixed/shift/wide/four-state and local/property reducers PASS; permanentfocus2legacy/2JSON,neighbors125legacy/92JSON,makecheck and independentdesign/code/ownershipreviewclear. Integrated92982exit0:legacy4981total4976pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66. JSON7147exit0:1873/0. UVM32316exit0:REAL DPI355/0/0. NFA58/58. Frontend49875exit0 allscenarios;installation restored andfivefrozenhashes match. Complete15release results-322hzu4s13SMOKE_PASS2COMPILE_FAIL,allstatuses/source/archivehashes unchanged vsL30. No full associative/UVM qualification claim.


### U14 — Native legacy recording ownership and lifecycle

- **Status:** CLOSED for bounded lifecycle scope on native ARM64; semantic `729edce3c`, test/CI coverage `79885f484`. DD038 remains OPEN.
- **Original gap:** Native owner/lifecycle API absent; both-edition DPI owner reducer
  compiled but failed at runtime. Original1.1b/c recording macro gaps preserved.
- **Scope:** Explicit legacy recorder, real lifecycle journal, owner/kind/state
  validation and cross-owner links using original1.1d API. No automatic install
  or fake attribute macro. Full typed capture/bootstrap remain required.
- **Evidence:** `evidence/campaign-20260908/u14/`; ACTIVE_WORK owns exact contract.

U14 final validation: U14 semantic729edce3c; test/Windows-CI coverage79885f484. Installed native lifecycle/exclusive-text checks both editions and POSIXIOfailure pass; original1.1d realchild/component,wrongowner,stream/transaction rollback,recorder switch,exclusive/replacedfiles and journal-failure tests pass. makecheck and independent design/code/failure-path reviews clear. Integrated20014 exit0:4981total4976pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66. JSON82380 exit0:1873/0. UVM57598 exit0:REAL DPI355/0/0. NFA45081 exit0:58/58. Releases32494 results-y5czc48y complete/baseline_valid13SMOKE_PASS2COMPILE_FAIL,all15status/source/archivehashes unchanged vsL31; separate1.1d lifecycle gate passes2017/2023. Frontend97996 exit0 allS1-S11;installation restored/six frozen hashes match. Bounded ARM64 local lifecycle validation only; typed capture/default installation/1.1b/c and fullUVM qualification remain open. Windows CI wired,execution not claimed.


### U15 — Lossless native recording value capture

- **Status:** SUSPENDED before implementation for proven L32 prerequisite; contract/reducers preserved under evidence/campaign-20260908/u15.
- **Scope:** Native packed width/sign/four-state bits, exact real values and
  strings, valid transaction routing and single evaluation. Review existing
  VPI metadata routes before committing to the API.
- **Remaining parent scope:** Complete declared schema, aggregates, object
  identity/cycles and deterministic default installation remain mandatory.
  No missing-macro workaround or full1.1b/c qualification in this increment.
- **Evidence:** `evidence/campaign-20260908/u15/`; ACTIVE_WORK owns contract.


### L32 — VPI string literal vector extraction

- **Status:** ACTIVE; proven prerequisite for U15.
- **Reducer:** Both editions return `"ABCD"` as0x44434241 instead of0x41424344;
  `"ABCDE"` also has reversed word placement. Shared loop additionally shifts
  signed bytes and initializes a word beyond the required allocation.
- **Scope:** Repair shared literal vector packing; preserve metadata and other
  conversions. IEEE5.9 and38.15; full typed recording remains open.
- **Evidence:** `evidence/campaign-20260908/u15/literal-vector-red.json` and
  `evidence/campaign-20260908/l32/`. Resume U15 after fullvalidation.
