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
