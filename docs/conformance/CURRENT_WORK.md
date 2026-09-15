# Current evidence and work

Documentation checkpoint: **2026-09-14**, reviewed against `main` revision
`9c8f716b1`; operational handoff reconciled after documentation merge
`fdbb8f34a` and local sync `3ab991187`. This page points to recorded evidence; it does not claim a fresh
run on every later checkout.

## Latest recorded compiler qualification

The [L96–L105 qualification record](session_logs/2026-09-15_compiler_batch_l96_l105_qualification.json)
records the passing seven-gate candidate `053e07d37`, with semantic source
`366ef2bf1`. The [batch session](session_logs/2026-09-15_compiler_batch_l96_l105.md)
links the ten bounded fixes and the preserved first-gate correction. Counts,
commands, source and artifact fingerprints live in the JSON record.

This qualifies that local candidate, not full IEEE, UVM or whole-application
support. Earlier [L85–L95](session_logs/2026-09-15_compiler_batch_l85_l95_qualification.json),
[L75–L84](session_logs/2026-09-14_compiler_batch_l75_l84_qualification.json),
[L65–L74](session_logs/2026-09-14_compiler_batch_l65_l74_qualification.json)
and [L64](session_logs/2026-09-14_constraint_function_presolve_qualification.json)
records retain their original revisions and limits.

Latest focused runtime increment: [L109 independent cyclic components](session_logs/2026-09-15_joint_ordered_independent_randc.md), with broad qualification pending and retained neighbor failures.

Latest focused coverage increment: [L110 constructor transition endpoints](session_logs/2026-09-15_constructor_transition_bins.md); broad qualification pending.

Latest focused constraint increment: [L111 coupled cyclic ordered solving](session_logs/2026-09-15_coupled_randc_ordered_solving.md); broad qualification pending.

## Application evidence

[Explicit-seed OpenTitan smoke replays](session_logs/2026-09-15_runtime_root_seed.md) pass
with the new root-seed runtime control; compile provenance and scope are
recorded separately from full application qualification.

The [L108 OpenTitan smoke replay](session_logs/2026-09-15_implicit_property_method_lookup.md)
records a fresh passing original-UVM-1.2 debug-crossbar workload after the
lookup repair. It is scoped to one core/default run; broader qualification
remains pending. A [runtime-only replay on L109](session_logs/2026-09-15_opentitan_l109_runtime_validation.json) also passes using the same compiled workload and default seed.

The [Caliptra include adapter and runtime replay](session_logs/2026-09-15_caliptra_include_overlay.md)
records the selected paired compile replay and a failed unmodified checked
`power2round_tb` run. Compilation gains do not imply runtime correctness.

The [September 15 focused application assessment](session_logs/2026-09-15_application_priority_assessment.md)
records a fresh OpenTitan UVM compile failure and selected Caliptra include-path
probes on semantic revision `366ef2bf1`. It does not replace the whole census.

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
The focused application replay above is newer; no newer whole-application census is claimed.

## History

The former continuation narrative is preserved in the
[July–September archive](session_logs/2026-09-14_current_work_archive.md).
Earlier checkpoints and failed attempts remain in the
[session logs](session_logs/README.md). Keep historical results revision-scoped;
update these pointers when new evidence is committed.

Latest focused SVA increment: [L112 multi-window first_match](session_logs/2026-09-15_multi_window_first_match.md); broad qualification pending.

Latest focused nested-constraint increment: [L113](session_logs/2026-09-15_nested_fixed_element_constraints.md); broad qualification pending.
