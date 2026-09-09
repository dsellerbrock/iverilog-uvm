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
