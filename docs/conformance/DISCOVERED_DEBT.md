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
