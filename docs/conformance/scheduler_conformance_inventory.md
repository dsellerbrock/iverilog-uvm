# Scheduler Conformance Inventory — M6B (2026-07-16)

Milestone **M6B — Scheduler conformance audit and remediation**. This is
the construct-level companion to the queue/region architecture audit
(`scheduler_audit_2026_07.md`): for each scheduling-relevant construct it
records the **current runtime path**, the **intended IEEE 1800-2017
clause-4 event region**, the **observed behaviour** (empirically probed),
and the **permanent test** that pins it.

M6 was relabeled **PARTIAL** in the 2026-07-16 truth audit because the
manifesto's scheduler-remediation scope (event-region inventory +
invariant checking + litmus tests) was not fully written down as a
construct inventory, even though the runtime was substantially
remediated. This document supplies that inventory; the remaining true
gaps are listed at the end.

Evidence: 18 event-region litmus probes run against the installed
simulator (scratch `m6b/l1..l18`), distilled into the permanent tests
below. "Region" names are IEEE 1800-2017 4.4.2.

## Construct inventory

| # | Construct | Runtime path (vvp) | Intended region | Observed | Permanent test |
|---|-----------|--------------------|-----------------|----------|----------------|
| 1 | Blocking assignment `=` | immediate in the vthread (`%store/*`), no scheduling | Active | correct: readers in the same process see the new value immediately | m6b_scheduler_litmus (3) |
| 2 | Nonblocking assignment `<=` | `schedule_assign_vector` → `nbassign` queue | NBA (4.4.2.3) | correct: RHS sampled in Active, applied in NBA; swap `a<=b;b<=a` swaps | m6b_scheduler_litmus (1,3); m6_sched_litmus |
| 3 | Named event trigger `->` | `%event`/set → propagate on `active` | Active | correct: `@e` / `wait(e)` waiters wake in the same slot | m6_sched_litmus; l3 |
| 4 | Nonblocking event trigger `->>` | scheduled event, optional `#delay` | Active (or delayed slot) | correct: `->> e` and `->> #N e` wake `@e`; fires after the current active pass | m6b_scheduler_litmus (4); l13 |
| 5 | `event.triggered` | slot-persistent trigger flag cleared at slot end (G08 fix) | Observed-through-slot (15.5.3) | correct: `-> e; if (e.triggered)` is true in the same slot | m6b_scheduler_litmus (7) |
| 6 | `fork/join`, `join_any`, `join_none` | `%fork` spawns vthreads (front-pushed to `active`); join waits | Active | correct: children run, join semantics honoured; `wait fork` blocks for all; `disable fork` kills siblings | m6b_scheduler_litmus indirectly; l10,l18 |
| 7 | `#0` inactive | `schedule_inactive` (or Re-Inactive in a program) | Inactive (4.4.2.2) | correct: `#0` runs after Active, before NBA; `#0` read sees pre-NBA value | m6_sched_litmus; m6b_scheduler_litmus (3) |
| 8 | Process scheduling (`initial`/`always`) | `schedule_vthread`; `always_comb` T0 via `schedule_t0_trigger` | Active / Inactive(T0) | correct: `always_comb` evaluates at time 0 | (existing always_comb tests) |
| 9 | Program / reactive execution | per-thread reactive flag (vpiProgram scope chain); `reactive`/`re_inactive`/`re_nbassign` queues | Reactive / Re-Inactive / Re-NBA (4.4.2.5-7) | correct: program blocking/`#0`/NBA land after the module regions | m6_reactive_region_test; l8,l14 |
| 10 | Assertion sampling / evaluation | Preponed sampling regs (M9); Observed evaluation (`schedule_at_observed`) | Preponed (4.4.2.1) / Observed (4.4.2.4) | correct: `$sampled`/`$past`/`$rose` use preponed values; SVA fires in Observed | m9_sva_engine_test; m9c_throughout_test |
| 11 | Clocking sampling (input skew) | `#1step` Preponed sample buffered at the clocking event | Preponed | correct: `cb.sig` reflects the sampled (pre-edge) value | (M8 clocking tests); l7 |
| 12 | Clocking drives (output skew) | buffered NBA-style drive at the clocking event | NBA / re-NBA | correct (M8): `cb.out <= v` drives at the clock edge | (M8 vif/clocking tests) |
| 13 | VPI callbacks | cbAtStartOfSimTime→`start`, cbReadWriteSynch→`rwsync`, cbReadOnlySynch→`rosync`, cbNextSimTime→time-advance, cbAfterDelay→generic | region-matched | correct for the mapped set; **cbNBASynch / post-NBA have no distinct home** (open) | (M12 VPI tests) |
| 14 | DPI imported tasks | run inline on the calling vthread (no suspension region) | Active (caller region) | correct for non-suspending tasks; a DPI task that consumes time is a **recorded corner** | (M10 DPI tests) |
| 15 | `$strobe` | `schedule_generic(rosync)` | Postponed (4.4.2.10) | correct: observes post-NBA values, ordered, once per slot | m6_sched_litmus; m6b_scheduler_litmus (2) |
| 16 | `$monitor` / `$monitoron` / `$monitoroff` | rosync-region print on change; on/off gate the active flag | Postponed | correct: prints last value per slot; on/off gate correctly | l5,l12 (probed) |
| 17 | `final` blocks | `schedule_final_list`, drained after the event loop | Postponed-of-simulation (3.5) | correct | (existing final tests) |
| 18 | `$finish` / `$stop` / **`$exit`** | `vpi_control(vpiFinish/vpiStop)`; **`$exit` NEW this session** | end of simulation | `$exit` (IEEE 24.7) now ends the calling program/simulation (was an undefined-systask error) | **m6b_exit_test** |
| 19 | Continuous assign `assign` | net functor propagation on `active` | Active (settles after NBA feed) | correct: reacts to NBA-updated drivers | m6b_scheduler_litmus (5) |
| 20 | Gate/assign inertial delay | scheduled net event with inertial cancellation | Active (delayed slot) | correct: a pulse shorter than the delay is cancelled | m6b_scheduler_litmus (6) |

## This session's fix — `$exit` (IEEE 1800-2017 24.7)

`$exit` was an undefined system task (hard vvp load error). Implemented
as a program-control task that ends the calling program; because Icarus
does not track per-program completion and the dominant use is a single
program testbench ending the test, `$exit` ends the simulation quietly
(no `$finish` banner). `vpi/sys_finish.c`: `sys_exit_calltf` +
registration, no-argument compile check reused.

**Recorded corner:** in a multi-program design where one program should
exit while others keep running, this ends the whole simulation at the
first `$exit`. Full per-program-completion tracking (and the
"simulation ends when the LAST program completes" rule of 24.7/3.9) is
deliberately NOT implemented here — it would change end-of-simulation
behaviour for the 57 ivtest cases + 3 harness tests that use program
blocks and risk byte-diff regressions; it is a separate, larger item.

## Remaining true scheduler gaps (M6B follow-up ledger)

- **Program-completion-ends-simulation** (24.7 / 3.9): a program that
  completes naturally does NOT end the simulation (verified: a test
  runs to its watchdog). `$exit` covers the explicit-exit case only.
- **cbNBASynch / post-NBA VPI callback regions**: no distinct home
  (mapped onto NBA).
- **DPI tasks that consume time**: run inline on the caller; no
  suspension-region model.
- **callf synchronous-drain → scheduled-call protocol**: the large,
  risky item behind `IVL_SCHED_CALLF` (default off), blocked by the
  function-call-atomicity requirement (13.4.3) — see
  `m6_scheduled_call_protocol.md`. Unchanged this session.
- **Wholesale queue promotion**: Active events created during
  Inactive/Reactive draining run in the same promoted batch rather than
  a strictly-later Active sub-pass. Observable only via region tracing;
  no known behavioural failure.

## Status

**M6 → M6B: PARTIAL, advancing.** The runtime scheduler is conformant on
all 20 constructs above for their common cases (18 litmus probes green);
`$exit` closes one gap; the follow-up ledger records the remaining true
gaps, none of which is a silent miscompile (they are absent features or
documented approximations). Permanent tests: `m6b_scheduler_litmus_test.sv`,
`m6b_exit_test.sv`, plus the pre-existing `m6_sched_litmus_test.sv`,
`m6_reactive_region_test.sv`, `m6_region_trace/`.
