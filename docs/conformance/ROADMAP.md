# Conformance roadmap

This page describes the program's goals. The [blocker registry](BLOCKERS.md)
owns the backlog; [ACTIVE_WORK](../../.ai/ACTIVE_WORK.yaml) names the selected
ticket. Milestone labels and old priority lists do not authorize work.

## Goals and evidence owners

| Goal | Where progress is recorded |
| --- | --- |
| IEEE 1800-2017 language and simulation semantics | [Clause matrix](matrices/ieee1800_2017_clause_matrix.md) |
| IEEE 1800-2023, including changed edition rules | [2023 survey](ieee1800_2023_delta.md) |
| IEEE 1800.2 / UVM compatibility and qualification | [UVM release matrix](uvm_release_matrix.md), with its bounded smoke scope |
| Real, unmodified OpenTitan and Caliptra verification | [Current evidence](CURRENT_WORK.md) and revision-specific application records |
| Formal-verification capability | [Manifesto](iverilog_ieee1800_uvm_manifesto.md); a proof backend remains future work |

These goals are separate. A library smoke pass, a successful compile, and a
complete verification run do not establish the same thing. UPF/IEEE 1801 is
deferred until the IEEE 1800 frontend is substantially closed.

## Choosing work

Follow the correctness and evidence rules in the
[manifesto](iverilog_ieee1800_uvm_manifesto.md) and the targeted-fix protocol in
[AGENTS](../../AGENTS.md). Newly demonstrated silent wrong answers, crashes,
corruption, and scheduler/runtime safety defects take priority. The coordinator
selects one concrete blocker, establishes its dependencies and required gates,
and records the authorization in ACTIVE_WORK.

## Historical milestone plans

The [former roadmap](session_logs/2026-09-14_roadmap_archive.md) preserves the
M0–M15 work breakdown, item IDs, old residual register, and dated checkpoints.
The [former manifesto planning sections](session_logs/2026-09-14_manifesto_planning_archive.md)
preserve milestone scope and design rationale. These archives explain older
references; their OPEN/DONE labels and ordering are historical.

Update the owning registry or evidence record when status changes. Link to
that record here instead of maintaining another feature list or test total.
