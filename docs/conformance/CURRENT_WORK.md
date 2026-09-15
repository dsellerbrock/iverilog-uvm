# Current evidence and work

Documentation checkpoint: **2026-09-14**, reviewed against `main` revision
`5c0f5588e`; operational handoff reconciled after documentation merge
`fdbb8f34a` and local sync `3ab991187`. This page points to recorded evidence; it does not claim a fresh
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

The campaign owner reconciled the handoff with the final L64 JSON above.
The earlier operational record is preserved in the
[handoff archive](session_logs/2026-09-14_campaign_handoff_archive.yaml).
L64 was published in [PR280](https://github.com/dsellerbrock/iverilog-uvm/pull/280)
and externally merged as `5c0f5588e`; this does not turn its local qualification
into cross-platform qualification.

[PR281](https://github.com/dsellerbrock/iverilog-uvm/pull/281), externally merged
as `9c8f716b1`, repairs build defects exposed by that publication. Its current revision, CI state, and exact next
command belong to CAMPAIGN. The local post-L64 batch has focused evidence but has not received broad
batch qualification;
its [L65](session_logs/2026-09-14_constraint_multiprefix_reductions.md) and
[L66](session_logs/2026-09-14_typed_array_return_elements.md),
[L67](session_logs/2026-09-14_packed_select_increment.md), and
[L68](session_logs/2026-09-14_array_packed_increment.md) session records
contain the focused evidence. No newer whole-application replay is claimed.

## History

The former continuation narrative is preserved in the
[July–September archive](session_logs/2026-09-14_current_work_archive.md).
Earlier checkpoints and failed attempts remain in the
[session logs](session_logs/README.md). Keep historical results revision-scoped;
update these pointers when new evidence is committed.
