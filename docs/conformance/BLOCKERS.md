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
- **Last verified revision:** 4bcbd9c7b fresh unmodified smoke completes115requests/230scoreboarditems with0UVMerrors/0fatals, but2SEQPRTZMBwarnings and TEST FAILED CHECKS. All360exportedfiles match prior replay. Earlier four-warning teardown frontier and reduced parent-kill mechanism are preserved; warning-count change does not qualify the application. Evidence: campaign-20260908/u01-after-l03.

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
