# Current evidence and work

Documentation checkpoint: **2026-09-14**, reviewed against `main` revision
`5c0f5588e`. This page points to recorded evidence; it does not claim a fresh
run on every later checkout.

## Latest recorded compiler qualification

The [L64 qualification record](session_logs/2026-09-14_constraint_function_presolve_qualification.json)
records a passing seven-gate batch for semantic revision `4bc02c51b`, integrated
locally as `0c6d5994a`. The subsequent change removed test whitespace; the
compiler/runtime artifacts were unchanged. The
[session's final qualification](session_logs/2026-09-14_constraint_function_presolve.md#final-seven-gate-qualification)
explains the checks and earlier failed attempts. Counts and artifact hashes
live in the JSON record rather than being copied here.

This is regression qualification of that candidate. It does not close clause
18, either IEEE edition, IEEE 1800.2, or whole application verification.

## Application evidence

The [September 13 OpenTitan/Caliptra census](session_logs/2026-09-13_opentitan_caliptra_rebaseline_after277.md)
is scoped to `631bba6e8`. It predates L43–L64 and is not an application replay
of the newer compiler. It includes failures and dependency/configuration debt;
completion of the census is not application success.

The [UVM release matrix](uvm_release_matrix.md) owns library acquisition and
release-smoke interpretation. The [2017 clause matrix](matrices/ieee1800_2017_clause_matrix.md)
and [2023 survey](ieee1800_2023_delta.md) own standards dispositions.

## Work selection and resumption

- [BLOCKERS](BLOCKERS.md): operational backlog and blocker status.
- [ACTIVE_WORK](../../.ai/ACTIVE_WORK.yaml): selected implementation ticket.
- [CAMPAIGN](../../.ai/CAMPAIGN.yaml): operational handoff, exact next command,
  and pending work. Check its revision before resuming; it may lag committed
  qualification evidence.
- [DISCOVERED_DEBT](DISCOVERED_DEBT.md): observations awaiting triage.
- [AGENTS](../../AGENTS.md): workflow, toolchain, and validation requirements.

At this documentation checkpoint, the committed campaign handoff still calls
L64 unqualified, while the later qualification record above marks it qualified.
Use the final record for L64 evidence; the campaign owner must reconcile its
handoff before selecting further implementation. This documentation cleanup
does not select a new blocker or modify active campaign state.

## History

The former continuation narrative is preserved in the
[July–September archive](session_logs/2026-09-14_current_work_archive.md).
Earlier checkpoints and failed attempts remain in the
[session logs](session_logs/README.md). Keep historical results revision-scoped;
update these pointers when new evidence is committed.
