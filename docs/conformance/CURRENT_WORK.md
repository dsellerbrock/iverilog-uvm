# Current evidence and work

Latest PR309 evidence: [required local qualification](session_logs/2026-09-21_pr309_local_qualification.json) passes on `09316da3d`; PR309 merged as `cb6f35b56` while CI was still running. This supersedes the earlier pending-local-gate notes below without changing their historical results or claiming full application qualification.

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

## Latest merged baseline

[PR308 merge record](session_logs/2026-09-21_pr308_merge.json): main is `482c3c89d`, with the nine-fix locally qualified batch merged after both Ubuntu CI jobs passed. Four other jobs were still running at observation. The [PR307 record](session_logs/2026-09-21_pr307_merge.json) retains the preceding baseline.

## Current focused implementation

The [port regression repair](session_logs/2026-09-21_port_regression_repair.json) removes the unnecessary behavioral carrier and preserves structural propagation. Shared qualification remains pending the event repairs.

The [six-fix installed focus](session_logs/2026-09-21_shared_six_focus.json) records the shared rebuild and passing permanent regressions. The [broad gate failed](session_logs/2026-09-21_shared_six_gate_failure.json), so qualification is pending repair. The [fresh stable-release replay](session_logs/2026-09-21_shared_six_release_retest.json) records current application results.

The [variable-output review](session_logs/2026-09-21_variable_output_integration_review.json) records private semantic and integration checks; shared qualification is pending.

The [Caliptra boundary trace](session_logs/2026-09-21_caliptra_rej_boundary_trace.json) records evidence for the remaining testbench scheduling race; the test still fails.

The [private Caliptra string replay](session_logs/2026-09-21_caliptra_string_private_replay.json) records progress past filename/vector generation and the remaining scoreboard failure. It is candidate evidence, not an integrated application pass. The [synthesis review](session_logs/2026-09-21_caliptra_string_synthesis_review.json) records the corrected candidate and its replay.

The [scope solver UNKNOWN repair](session_logs/2026-09-21_scope_solver_unknown_fix.json) is focused-tested on the next-batch branch. The [long fixed antecedent repair](session_logs/2026-09-21_long_fixed_antecedent_fix.json) is also focused-tested. Broad next-batch qualification is pending; both fixes are separate from PR307.

The [constraint object-method repair](session_logs/2026-09-21_constraint_object_method_receiver.json) has paired focused and neighboring regression evidence; broad batch gates remain pending.

The [bare enum-name repair](session_logs/2026-09-21_enum_bare_name_type.json) has paired focused and enum-neighbor evidence, pending broad batch gates.

The [self-package cast repair](session_logs/2026-09-21_self_package_type_cast.json) and [signed coverage range repair](session_logs/2026-09-21_signed_cover_range_resolution.json) have paired focused evidence. Required broad batch gates remain pending.

The [pwrmgr startup replay](session_logs/2026-09-21_pwrmgr_startup.json) reaches runtime but fails HDL-path checking; compiler fallback warnings also exclude application qualification.

The [nine-fix checkpoint release retest](session_logs/2026-09-21_batch_nine_release_retest.json) records fresh stable-source application results and the current broad-gate failure. Full batch qualification remains pending.

## Latest recorded compiler qualification

The [nine-fix batch qualification](session_logs/2026-09-21_nine_fix_batch_qualification.json) records all seven required local gates passing on semantic revision `c1635efe9`, including the synthesis metadata repair. CI, private next-batch candidates, and full application/standards qualification remain separate.

The [next-candidate release retest](session_logs/2026-09-21_next_candidate_release_retest.json) preserves earlier bounded OpenTitan and Caliptra runtime results, including source/binary fingerprints and clean release pins. It does not qualify the pending compiler patches. The [published-candidate retest](session_logs/2026-09-21_published_candidate_release_retest.json) and September 20 static census remain revision-scoped historical evidence.

The [canonical graph and cleanup record](session_logs/2026-09-21_canonical_graph_cleanup.json) records the restored main checkout, shared graph refresh, retired worktree, preserved branch, and cleanup audit.

The [September 21 batch qualification](session_logs/2026-09-21_compiler_batch_qualification.json) records all seven local gates passing for semantic revision `8ab943352`. It supersedes the earlier batch checkpoints below for local compiler validation; GitHub CI and application revision limits remain separate.

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

The [type-first candidate release retest](session_logs/2026-09-21_typed_candidate_release_retest.json)
records the later candidate fingerprints, fresh unmodified release runtime results,
remaining GPIO failure, and cleanup disposition. This bounded run does not qualify
the pending compiler batch.

The [September 21 bounded release retest](session_logs/2026-09-21_stable_release_retest.json)
records fresh compiler/runtime fingerprints, unmodified Caliptra unit and OpenTitan
peripheral-crossbar results, GPIO failure, and cleanup. It covers the recorded
uncommitted candidate; it does not qualify the pending compiler batch.

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

The [state-selected constraint record](session_logs/2026-09-21_state_selected_fixed_array_constraints.json) tracks the next paired focused candidate and its validation status.

The [reset-only synthesis record](session_logs/2026-09-21_reset_only_synthesis.json) records the next paired runtime checkpoint.

The [restoration CI checkpoint](session_logs/2026-09-21_restoration_ci_checkpoint.json) records live exact-head platform status for PR306, independently of the current batch.

Latest bounded application retest: [queue-validity candidate release evidence](session_logs/2026-09-21_queue_candidate_release_retest.json). This does not supersede full compiler qualification.

The [constraint cast/distribution checkpoint](session_logs/2026-09-21_constraint_cast_distribution_checkpoint.json)
records focused and neighboring regression evidence for `969853350`, pending broad batch qualification.

The [September 21 candidate release retest and cleanup](session_logs/2026-09-21_candidate_release_retest_and_cleanup.json)
records fresh pinned-release application results and disposable binary removal.
It does not qualify the current uncommitted compiler candidate.

The [synthesis and wide-index focused checkpoint](session_logs/2026-09-21_synthesis_and_wide_index_focus.json) records paired-edition runtime and neighboring-test evidence. Required broad batch gates remain pending.

The [repaired-candidate release retest](session_logs/2026-09-21_repaired_candidate_release_retest.json) supersedes the earlier application snapshot for the latest elaboration repairs. Full batch qualification remains pending.

The [empty-branch enable repair](session_logs/2026-09-21_empty_branch_enable_repair.json) records the JSON-discovered synthesis regression and focused recovery; the final broad run is tracked in CAMPAIGN.

Latest bounded release replay: [2026-09-21 current candidate](session_logs/2026-09-21_current_release_retest.json). Exact pins, commands, runtime outcomes and qualification limits are recorded there.

Latest packed-VPI local checkpoint: [paired tests and affected-suite evidence](session_logs/2026-09-21_packed_vpi_integration.json). Broad batch qualification remains pending.

The [constraint divide/remainder error repair](session_logs/2026-09-21_constraint_divmod_zero.json) has paired focused and neighboring runtime evidence; broad batch gates remain pending.

The [joint ordered-randc repair](session_logs/2026-09-21_joint_ordered_randc.json) has paired runtime, distribution and rollback evidence; batch gates remain pending.

Latest bounded stable-application replay: [qualified nine-fix candidate](session_logs/2026-09-21_qualified_nine_release_retest.json). Exact corpus pins, binary fingerprints, commands, pass/failure evidence and scope limits are in that record.

Draft review checkpoint: [PR #309](https://github.com/dsellerbrock/iverilog-uvm/pull/309) publishes `b03bccdf9` for review. It is not a qualified baseline; the PR lists the preserved local regression failures and required repair/requalification. Current private repair lanes and the uncommitted automatic-context integration are recorded in `.ai/CAMPAIGN.yaml`.

[Event runtime repair checkpoint](session_logs/2026-09-21_event_runtime_regression_repair.json) supersedes the runtime failure status above for its recorded source/tools. Synthesis repairs and broad requalification remain pending; PR #309 stays draft.

[Synthesis event repair evidence](session_logs/2026-09-21_synthesis_event_regression_repair.json) records the successful replay of all earlier failing legacy/VPI cases and new paired boundary tests. [Fresh pinned release replay](session_logs/2026-09-21_repaired_release_replay.json) and [initial PR309 CI classification](session_logs/2026-09-21_pr309_initial_ci.json) preserve application limitations and the Windows export repair. Full repaired-revision gates are pending.

The [OpenTitan regex trace](session_logs/2026-09-21_opentitan_regex_attribution.json) attributes the current GPIO/pwrmgr startup errors to a direct glob-shaped argument reaching the strict legacy regex API. It establishes no application pass or new compiler fix.

The [OpenTitan crossbar expansion](session_logs/2026-09-21_opentitan_crossbar_expansion.json) records the upstream zero-delay variant pass and random-test timeout without workload reduction. It does not qualify the full suite.

The [PR309 CI checkpoint](session_logs/2026-09-21_pr309_ci_checkpoint.json) records Ubuntu 24.04 success on the merged compiler revision; remaining platforms were still running at capture.

Latest SPI Host compiler checkpoint: [fixed member-array constraint evidence](session_logs/2026-09-21_spi_host_member_array_focus.json). Required broader checks and application blockers remain explicit in the record.

The [OpenTitan configuration correction and replay](session_logs/2026-09-21_opentitan_regex_configuration.json) supersedes the earlier no-configuration-mismatch conclusion. Application qualification remains limited as recorded there.
