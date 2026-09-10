# Discovered debt (parking lot)

This file exists so that finding a defect while working a different
`.ai/ACTIVE_WORK.yaml` ticket never becomes an excuse to widen that ticket.

**Recording an unrelated discovery completes the active agent's
responsibility for it during the current ticket.** Do not fix it, do not
investigate it further, do not expand scope to cover it. Record it below and
return to the active work item.

Triage (promoting an entry here into `docs/conformance/BLOCKERS.md`, or
opening a new `.ai/ACTIVE_WORK.yaml` ticket for it) is a separate activity
done outside any single targeted-fix run.

## Entry format

```markdown
### DD-<NNN> — <short observation>

- **Discovered while working:** <active blocker ID, or "governance
  bootstrap" / other non-blocker task>
- **Observation:** <what was seen>
- **File/function:** <path:line or symbol, if known>
- **Possible clause:** <IEEE clause if applicable, else N/A>
- **Evidence:** <how it was noticed — log excerpt, source read, etc.>
- **Reproducer status:** none / sketched / confirmed
- **Triage status:** untriaged / promoted to BLOCKERS.md as <ID> / declined (why)
```

---

No entries yet. This governance-bootstrap pass did not investigate
implementation code for defects (that would itself be an audit, which is
out of scope here) — nothing was discovered during this ticket that
requires parking. Use the format above for the next agent's discoveries.


### DD-001 — joint active-randc prepass and enumeration-cap interaction

- **Discovered while working:** Z01A
- **Observation:** Source review found a randc draw before complete component enumeration. A draw-dependent over-cap failure could condition successful calls on the selected value; not reproduced or claimed as a confirmed defect.
- **File/function:** vvp/vvp_z3.cc, z3_solve_pass_ randc prepass and exact_joint component enumeration.
- **Possible clause:** IEEE 1800-2017 18.4.2 / global constraint distributions; exact applicability needs triage.
- **Evidence:** Independent Z01A source review; ordered active-randc is explicitly excluded/rejected by Z01A.
- **Reproducer status:** sketched
- **Triage status:** untriaged


### DD-002 — associative member foreach loses string key type

- **Discovered while working:** L01
- **Observation:** foreach(boxes[selector].values[key]) with class member values[string] declares key as int and iterates zero entries. Same output and int key declaration with retained pre-L01 compiler and campaign runtime; not caused by the selected-prefix fix.
- **File/function:** pform_make_foreach_declarations / foreach_index_type_t unindexed member type resolution.
- **Possible clause:** IEEE 1800-2017/2023 12.7.3 implicit index type.
- **Evidence:** evidence/campaign-20260908/l01/typed*.sv, .vvp and logs; old compiler from preserved string-array-param-after253 worktree, a diagnostic comparison rather than a campaign qualification gate.
- **Reproducer status:** confirmed
- **Triage status:** untriaged; no repair included in L01.

### DD-003 — Boolean event-expression driver discards automatic activation context

- Active blocker: L02. Record-only; not a regression from L02.
- Observation: simultaneous task activations using posedge (value[2] | 1'b0)
  both report transition time 2 instead of 2,3.
- Mechanism: vvp/logic.cc vvp_fun_boolean_ receives no retained context and
  vvp_fun_or::run_run sends its result with context 0; input storage is shared.
- Authority: IEEE 1800-2017/2023 6.21 and 9.4.2; expression event transition
  must use the invocation's value.
- Evidence: u01-loop/history-expression-preexisting.sv, history-baseline.log,
  history-baseline.vvp; fresh e0dab7221 compiler rebuilt into baseline-tools
  with original frame selection. Identical 2,2 failure on baseline and L02.
- Reproducer status: reproduced; triage: pending. General automatic Boolean
  event-expression correctness is not claimed by L02.

### DD-004 — Unchanged partial write can manufacture a default-bit negedge

- Active blocker: L02; record-only, not introduced by frame selection.
- Observation: default bit vector 0, unchanged value[2:1]=0 at t1 wakes
  negedge value[0], although the intended first negedge is at t3.
- Mechanism: vvp_fun_signal4_aa::reset_instance emits no initial sample;
  recv_vec4_pv sends even an unchanged vector, exposing probe history X.
- Authority: IEEE 1800-2017/2023 6.8 and 9.4.2.
- Evidence: u01-loop/default-negedge.sv and baseline/candidate logs, both
  fail at t1. Original e0dab7221 compiler frame layout also fails with the
  candidate runtime; native probe path has no ancestor history to seed.
- Reproducer status: reproduced; triage: pending. No default-negated-edge
  qualification claim is made by L02's passing positive-edge control.

### DD-005 — Non-fanout assertion paths omit vacuous user pass actions

- Active blocker: S03; record-only outside the endpoint aggregation path.
- Observation: `tests/sva_recursive_consequent_test.sv` executes17 enabled
  starts; the fixed negated consequence has one nonvacuous success and one
  failure, but reports only1pass rather than16 including vacuity. Existing
  until/eventual controls similarly count only nonvacuous successes.
- Mechanism: unchanged non-endpoint NFA/legacy implication handling suppresses
  vacuous pass dispatch. S03 repairs only the split endpoint parent path.
- Authority: IEEE1800-2017/2023 16.12.7; a no-match antecedent succeeds.
- Evidence: campaign-20260908/s03/recursive-red-2017.log and2023.log;
  old baseline test already expects1pass, and the unaffected source path
  omits its vacuous action. Nested/throughout parent paths now report17.
- Reproducer status: observed in both editions; triage pending. Do not infer
  general vacuity qualification from the S03 endpoint-path controls.

### DD-006 — nested parameterized sequence alias does not expand

- **Discovered while working:** S04.
- **Observation:** Pair(x,y) defined as x ##2 y works when reused directly with distinct actuals in OR/AND antecedents. Wrapping Pair(a,b) and Pair(c,d) in named Left/Right aliases instead reports No function named Pair during elaboration.
- **File/function:** pform.cc sequence splicing / parameter-window antecedent normalization; causal triage pending.
- **Possible clause:** IEEE 1800-2017/2023 sequence declarations and argument binding; exact clause pending triage.
- **Evidence:** evidence/campaign-20260908/s04/window-nested-alias.sv and window-nested-alias.log. Same four errors with compiler rebuilt from validated61ca5f336: window-nested-baseline.log. Current source/build restored afterwards; installed candidate tools unchanged during running gates.
- **Reproducer status:** confirmed before S04; direct parameterized reuse is a passing control.
- **Triage status:** untriaged, record-only; no repair included in S04.

### DD-007 — symbolic repetition still reports consequent endpoint verdicts

- **Discovered while working:** S04 oracle review.
- **Observation:** Symbolic ranged/unbounded antecedent lowering retains per-endpoint consequent pass/fail actions, rather than aggregating one parent assertion verdict. S03 repaired the NFA parent model, not this separate symbolic engine. S04 only repairs previously missing vacuity for ages that never matched.
- **File/function:** pform.cc sva_parameter_repeat_try_assertion_ r_pass_req/r_fail_req and endpoint counts.
- **Possible clause:** IEEE 1800-2017/2023 16.12.7 and 16.14.1.
- **Evidence:** Existing validated sv_assert_repeat_parameter_override and sv_assert_repeat_parameter_smoke tests explicitly expected multiple endpoint actions before S04. Independent S04 review derived their new totals by adding vacuity; these remain compatibility checks, not per-attempt standards qualification. No new regression inferred from those totals.
- **Reproducer status:** existing regression stimuli retained; parent-verdict reducer needs a deliberate selection boundary.
- **Triage status:** resolved within S05 locally validated fixed ##0/##1 symbolic repetition scope. Broader symbolic consequent-delay overrides remain DD-008 and are not covered by this qualification.

### DD-008 — symbolic consequent delay override uses the default

- **Discovered while working:** S05 boundary reducer construction.
- **Observation:** `a[*LO:HI] |-> ##D q` with defaults LO1/HI2/D0 and instance D1 passes at the second tick instead of awaiting the final child at tick3; making q false at tick3 produces no failure. Explicit literal ##1 is a passing control in the S05 paired reducers.
- **File/function:** pform.cc cycle-delay normalization and symbolic repetition probe; causal triage pending.
- **Possible clause:** IEEE1800-2017/2023 6.20.2,16.9,16.12.7; exact delay-normalization cause unverified.
- **Evidence:** campaign-20260908/s05/parameter-delay-override.sv and .log; current candidate produces EARLY1/0 then1/0. First observed before the S05 parent edit; no retained pre-S05 isolated reducer result, so baseline comparison remains required.
- **Reproducer status:** reduced current failure; literal-delay control passes.
- **Triage status:** promoted to S06 after S05 local qualification; paired reducer remains red on validated a76c9f67a. S05 does not claim qualification of symbolic consequent-delay overrides.
