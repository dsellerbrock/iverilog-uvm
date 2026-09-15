# Documentation

Start with the [project README](../README.md) for installation and a first run.
This index separates maintained guidance from dated evidence so each topic has
one owner. Documentation reviewed against `5c0f5588e` on 2026-09-14.

## Usage and tools

| Topic | Canonical document |
| --- | --- |
| Build and first simulation | [README](../README.md) |
| UVM tests, plusargs, DPI choices, troubleshooting | [UVM usage](uvm.md) |
| UVM resource discovery, loading, platform internals | [UVM frontend](uvm_frontend.md) |
| Acquiring UVM versions and interpreting release results | [Release matrix](conformance/uvm_release_matrix.md) |
| Language-edition selection and gate implementation | [Edition gates](conformance/language_edition_gates.md) |
| OpenTitan census setup and classification | [Matrix runner](conformance/opentitan_matrix.md) |
| Windows packaging | [MSYS2 recipe](../msys2/README.md) |
| Personal IEEE reference files | [Standards references](standards/README.md) |
| Upstream compiler/target/VPI documentation | [Documentation/](../Documentation) |

## Policy, status, and work

| Question | Owner |
| --- | --- |
| What are the correctness and completion requirements? | [Manifesto](conformance/iverilog_ieee1800_uvm_manifesto.md) |
| What workflow and toolchain should an agent use? | [AGENTS](../AGENTS.md) |
| What are the program goals? | [Roadmap](conformance/ROADMAP.md) |
| What semantics have evidence? | [2017 matrix](conformance/matrices/ieee1800_2017_clause_matrix.md), [2023 edition relationships](conformance/ieee1800_2023_delta.md) |
| What is the latest committed regression/application evidence? | [CURRENT_WORK](conformance/CURRENT_WORK.md) |
| What remains to be addressed? | [BLOCKERS](conformance/BLOCKERS.md) |
| What is selected now, and how should it resume? | [ACTIVE_WORK](../.ai/ACTIVE_WORK.yaml), [CAMPAIGN](../.ai/CAMPAIGN.yaml) |
| Where do untriaged observations go? | [DISCOVERED_DEBT](conformance/DISCOVERED_DEBT.md) |
| Which regression scope is appropriate? | [Regression policy](conformance/REGRESSION_POLICY.md) |
| What belongs in a PR? | [PR template](../.github/pull_request_template.md) |

The matrices retain dated refinements and initial audit tables. Read the
revision and subset boundary before treating a statement as current. New
qualification evidence may be newer than an operational handoff; CURRENT_WORK
calls out known discrepancies without selecting new implementation work.

## Focused evidence and history

These explain designs and past observations. They do not independently set
current feature status, priorities, or test totals.

- [Session logs and preservation policy](conformance/session_logs/README.md):
  all dated session records, including failed attempts and cleanup archives.
- [OpenTitan gap ledger](conformance/opentitan_gap_ledger.md) and
  [clocking disposition](conformance/m8_clocking_disposition.md): focused,
  revision-scoped evidence linked to the overall conformance records.
- Scheduler: [architecture audit](conformance/scheduler_audit_2026_07.md),
  [conformance inventory](conformance/scheduler_conformance_inventory.md),
  [synchronous-call design](conformance/m6_callf_rearchitecture.md),
  [superseded scheduled-call proposal](conformance/m6_scheduled_call_protocol.md),
  [automatic-storage notes](conformance/auto_var_storage_refactor_notes.md).
- Assertions and DPI: [NFA design](conformance/m9_nfa_design_2026-07-19.md),
  [property-expression design](conformance/property_expr_recursion_design.md),
  [DPI export design](conformance/dpi_export_design_2026-07-20.md).
- Application/probe audits: [first OpenTitan assessment](conformance/opentitan_compat_2026-07-29.md),
  [assertion roots](conformance/repros/ot_sva_assertion_roots.md),
  [stress findings](conformance/m7_stress_findings_2026-07-18.md),
  [July findings ledger](conformance/findings_ledger_2026-07-31.md),
  [capability probes](../tests/capability/README.md),
  [test-suite audit](conformance/test_suite_audit_2026-07-17.md),
  [July UVM ledger](../.github/regression/UVM_DEBT.md).
- Earlier planning: [milestone truth audit](conformance/milestone_truth_audit_2026-07-16.md),
  [closure assessment](conformance/m_closure_assessment_2026-07-18.md),
  [frontier roadmap](conformance/frontier_roadmap_2026-07-17.md),
  [phase proposal](../PHASE_PROPOSAL.md), [gap audit](claude/uvm_ieee1800_gap_audit_2026_05.md),
  [gap plan](claude/uvm_gap_plan.md), [phase README](history/2026-05_phase_history_readme.md),
  [technical design history](../CHANGES.md).

## Keeping docs current

Update the owning document and link to it elsewhere. Keep commands in usage
guides, standards dispositions in the matrices, blocker state in the registry,
and measured results in revision-scoped evidence. The 2023 survey records
edition differences or paired evidence instead of copying the 2017 narrative.

Do not turn historical pass counts or OPEN/NEXT labels into current claims.
Retain dated evidence, including failures; correct it with a scoped note.
A documentation update does not establish new simulator qualification.
