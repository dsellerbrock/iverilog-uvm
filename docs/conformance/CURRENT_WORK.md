# Current evidence and work

Documentation checkpoint: **2026-09-14**, reviewed against `main` revision
`9c8f716b1`; operational handoff reconciled after documentation merge
`fdbb8f34a` and local sync `3ab991187`. This page points to recorded evidence; it does not claim a fresh
run on every later checkout.

## September 20 merged-baseline restoration

The [restoration record](session_logs/2026-09-20_merged_baseline_restoration.md)
identifies source/test changes missing after the three PR merges and the
reviewed checkpoint used to restore them. The local qualification is linked below.

## September 20 integration review

The [PR review and repair record](session_logs/2026-09-20_pr_review_repairs.md)
identifies the three reproduced defects and their repairs. PR306 restored
the reviewed compiler/test tree to main. Resumption and
validation state belong to ACTIVE_WORK and CAMPAIGN linked below.

## Latest recorded compiler qualification

The [restored-baseline qualification](session_logs/2026-09-20_restored_baseline_qualification.json)
records all seven local gates passing for semantic revision `e90059a07`,
whose compiler/test tree matches merged main `0998f058a`. Counts, commands,
artifact fingerprints and edition limits live in that record. GitHub CI
remains separate from this local evidence.

The earlier [L96–L105 qualification](session_logs/2026-09-15_compiler_batch_l96_l105_qualification.json)
and [batch session](session_logs/2026-09-15_compiler_batch_l96_l105.md)
retain their revision-scoped results.

This qualifies that local candidate, not full IEEE, UVM or whole-application
support. Earlier [L85–L95](session_logs/2026-09-15_compiler_batch_l85_l95_qualification.json),
[L75–L84](session_logs/2026-09-14_compiler_batch_l75_l84_qualification.json),
[L65–L74](session_logs/2026-09-14_compiler_batch_l65_l74_qualification.json)
and [L64](session_logs/2026-09-14_constraint_function_presolve_qualification.json)
records retain their original revisions and limits.

## Application evidence

The [September 20 stable-release replay checkpoint](session_logs/2026-09-20_stable_release_replay.json)
records the fresh Caliptra static census and unmodified power2round unit-runtime
pass with warnings, unmodified OpenTitan TL-agent and Earlgrey xbar UVM test
verdicts with a runtime warning, the completed census, and audited cleanup. These bounded
results do not establish full-chip or complete application qualification.

The [September 15 OpenTitan `xbar_smoke` UVM pass](session_logs/2026-09-15_opentitan_xbar_smoke_patched.md)
is the first UVM test to reach `TEST PASSED CHECKS` against a stable OpenTitan
release (Earlgrey-PROD-M6). **It is a patched-release result, not an
unmodified-source pass** — one `dv_report_catcher.sv` source correction was
required for a nonstandard `foreach` spelling (upstream syntax defect, not an
Icarus gap; see the log for the IEEE 1800 §12.7.3 citation). The original,
unmodified file's failure is preserved, not overwritten.

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

The [grouped clocked consequent record](session_logs/2026-09-20_grouped_clocked_consequent.md) provides focused paired-edition evidence pending the next batch qualification.

The [masked memory synthesis record](session_logs/2026-09-20_masked_memory_synthesis.json) contains the next paired focused checkpoint, pending batch qualification.

The [variable-row assignment record](session_logs/2026-09-20_variable_row_assignment.json) contains paired focused evidence and the remaining Ibex synthesis boundary.
