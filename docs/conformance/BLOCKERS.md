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
- **State:** IN_PROGRESS (resumed: sequence-parent warnings after checked traffic completes)
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
- **Last verified revision:** b0ac00f47 fresh unmodified-source smoke: L01 fixes address routing and scoreboard mismatch; three responses match, fourth response is aborted as before L01, outstanding-request error and 300s timeout remain. U01 remains unqualified.

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

- **Area / edition:** Assertions/SVA / edition-agnostic
- **State:** OPEN
- **Confidence:** RECORDED
- **Evidence / reproducer:** `docs/conformance/ROADMAP.md` /
  `docs/conformance/matrices/ieee1800_2017_clause_matrix.md` record
  overlapping implication across different clock domains as explicitly
  excluded by the current lowering strategy.
- **What it blocks:** Multi-clock-domain SVA properties, common in
  real DUTs with independent clock/reset trees.
- **Closure requirements:** Coincident-edge-aware lowering with
  source-order-independent antecedent/consequent start behavior; positive
  and negative tests across at least two independent clocks.
- **Last verified revision:** not re-verified since the audit.

### V01 — Exact merged type-coverage bin universe (coverage correctness)

- **Area / edition:** Functional coverage / edition-agnostic
- **State:** OPEN
- **Confidence:** SOURCE
- **Evidence / reproducer:** `vvp/class_type.cc`'s `type_coverage` uses a
  maximum registered dynamic-family size raised to the hit count — not an
  exact union for arbitrary disjoint instance bin sets.
- **What it blocks:** Correct type-coverage denominators/percentages for
  class-type coverage with disjoint or partially overlapping instance bin
  sets; any claim of coverage-number correctness beyond the all-hit case.
- **Closure requirements:** Disjoint and overlapping instance domains with
  known union sizes, including partial (non-100%) coverage results checked
  against a hand-computed oracle, not just "coverage reaches 100%."
- **Last verified revision:** not re-verified since the audit.

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
