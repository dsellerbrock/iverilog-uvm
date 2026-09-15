# Current evidence and work

Documentation checkpoint: **2026-09-14**, reviewed against `main` revision
`9c8f716b1`; operational handoff reconciled after documentation merge
`fdbb8f34a` and local sync `3ab991187`. This page points to recorded evidence; it does not claim a fresh
run on every later checkout.

## Latest recorded compiler qualification

The [L75–L84 qualification record](session_logs/2026-09-14_compiler_batch_l75_l84_qualification.json)
records the passing seven-gate batch at `304507aeb`, with semantic source
`240dd5f6f`. The [batch session](session_logs/2026-09-14_compiler_batch_l75_l84.md)
links each bounded implementation and its focused evidence. Counts, commands and
artifact fingerprints live in the JSON record.

This qualifies that local candidate, not full IEEE, UVM or whole-application
support. Earlier [L65–L74](session_logs/2026-09-14_compiler_batch_l65_l74_qualification.json)
and [L64](session_logs/2026-09-14_constraint_function_presolve_qualification.json)
records retain their original revisions and limits.

## Newer focused implementation evidence

[L85 ordered distributions](session_logs/2026-09-14_joint_ordered_distribution.md),
[L87 selected-element ordering](session_logs/2026-09-14_joint_element_ordering.md),
[L88 dynamic-array ordering](session_logs/2026-09-15_joint_dynamic_element_ordering.md),
[L89 queue ordering](session_logs/2026-09-15_joint_queue_element_ordering.md),
[L86 multiclock antecedents](session_logs/2026-09-15_multiclock_bounded_antecedents.md),
and [L91 finite repetition](session_logs/2026-09-15_multiclock_boolean_repetition.md)
record newer focused implementations. They do not replace the broad qualification above.

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

The campaign owner reconciled the handoff with the final L64 JSON linked above.
The earlier operational record is preserved in the
[handoff archive](session_logs/2026-09-14_campaign_handoff_archive.yaml).
L64 was published in [PR280](https://github.com/dsellerbrock/iverilog-uvm/pull/280)
and externally merged as `5c0f5588e`; this does not turn its local qualification
into cross-platform qualification.

[PR281](https://github.com/dsellerbrock/iverilog-uvm/pull/281), externally merged
as `9c8f716b1`, repairs build defects exposed by that publication. Its current revision, CI state, and exact next
command belong to CAMPAIGN. The post-L64 batch is locally qualified by the
latest record above. Publication status and subsequent work remain in CAMPAIGN.
No newer whole-application replay is claimed.

## History

The former continuation narrative is preserved in the
[July–September archive](session_logs/2026-09-14_current_work_archive.md).
Earlier checkpoints and failed attempts remain in the
[session logs](session_logs/README.md). Keep historical results revision-scoped;
update these pointers when new evidence is committed.
