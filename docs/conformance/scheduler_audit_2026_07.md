# vvp Scheduler Architecture Audit — 2026-07-12

Manifesto-v2 "Scheduler remediation program" audit (M6 gate). Evidence:
`vvp/schedule.h`, `vvp/schedule.cc` (event queues and main loop),
`vvp/vthread.cc` (thread execution, callf, fork), `vvp/vpi_priv.cc`
(callback registration), plus defects root-caused in this session's
checkpoints. IEEE references are to 1800-2017 clause 4 (scheduling
semantics) region names; the mapping below records what EXISTS, not a
claim of conformance.

## 1. Queue inventory (per time slot: `struct event_time_s`, schedule.cc)

| Queue | Enqueued by | Drained |
|---|---|---|
| `start` | `schedule_at_start_of_simtime` (cbAtStartOfSimTime) | at time advance, after `vpiNextSimTime()` |
| `active` | `schedule_vthread(delay=0)`, `schedule_set_vector`, propagate/force events, promotions | main loop, one event at a time |
| `inactive` | `schedule_inactive` (#0), `schedule_t0_trigger` (always_comb T0) | promoted wholesale into `active` when `active` empties |
| `nbassign` | `schedule_assign_vector` / `schedule_assign_array_word` (NBA), `schedule_vthread(delay>0)` lands via new slot's active | promoted into `active` after `inactive` |
| `rwsync` | `schedule_generic(sync_flag=1, ro_flag=0)` (cbReadWriteSynch) | promoted into `active` after `nbassign` |
| `rosync` | `schedule_generic(sync_flag=1, ro_flag=1)` (cbReadOnlySynch, `$strobe`, `$monitor`) | `run_rosync` at slot teardown; writes guarded by `schedule_at_rosync()` |
| `del_thr` | `schedule_del_thr` | with rosync at slot teardown |

Global (non-slot) lists: `schedule_init_list` (pre-simulation variable
init, drained before `vpiStartOfSim`), `schedule_final_list` (final
blocks, drained after the event loop).

Slot sequencing (main loop, `schedule_simulate`): on time advance →
`vpiNextSimTime` → `start` queue → loop { pop `active`; when empty:
`inactive`→active, then `nbassign`→active, then `rwsync`→active, then
`run_rosync` + delete slot }.

## 2. IEEE 1800-2017 region mapping

| IEEE region (4.4.2) | vvp | Status |
|---|---|---|
| Preponed | `preponed` | **PRESENT** (2026-07-14, item 4): drains at slot entry before Active; `schedule_at_preponed` entry point; no consumer yet (SVA/clocking sampling arrives M8/M9) |
| Active | `active` | present |
| Inactive | `inactive` | present (#0) |
| Pre-NBA (cbNBASynch) | — | not distinct from NBA |
| NBA | `nbassign` | present |
| Post-NBA | — | absent |
| Observed | `observed` | **PRESENT** (2026-07-14, item 4): promoted into active after NBA, before the reactive set; `schedule_at_observed` entry point; no consumer yet (SVA evaluation arrives M9) |
| Reactive / Re-Inactive / Re-NBA | `reactive` / `re_inactive` / `re_nbassign` | **PRESENT** (2026-07-12, remediation item 2): program-block processes carry a per-thread reactive flag (scope-chain `vpiProgram` + inheritance to spawned children); event wake chains are partitioned by region; program #0 → Re-Inactive; program NBAs → Re-NBA. Promotion order: active ← inactive ← nbassign ← reactive ← re-inactive ← re-nba ← rwsync. Test: `tests/m6_reactive_region_test.sv` |
| Pre-Postponed (cbReadWriteSynch) | `rwsync` | present; correctly re-promotes into active so writes re-trigger evaluation |
| Postponed (cbReadOnlySynch) | `rosync` | present with rosync write guard |

## 3. Implicit-ordering dependencies (audit point 3)

- `schedule_vthread(..., push_flag=true)` pushes to the FRONT of
  `active`; `%fork` relies on this to run children ahead of pending
  NBAs. Ordering is a property of queue position, not a declared
  region.
- Same-queue events run in insertion order (circular singly linked
  list, append at tail); several UVM-phasing behaviors observed in this
  fork depend on that stability (see uvm_gap_plan Phase 64 notes and
  the I5 static-init ordering fix, add_process_at_tail).
- `inactive` promotion is wholesale (whole queue moved), so #0 events
  scheduled DURING inactive draining land in the next promotion round —
  consistent with LRM iteration, but implicit.

## 4/5. Direct thread execution and synchronous-child assumptions

- `%callf/*` (vthread.cc `do_callf_void` and friends) executes the
  callee thread synchronously inside the caller's opcode dispatch,
  bypassing the scheduler. Three defects root-caused this session live
  here: the chunk-boundary `%fork`/`%join_detach` misparse (Phase 64),
  the "callf child did not end synchronously" join-wait fallback (G48,
  suppressed diagnostic), and the same-scope returned-frame shadowing
  (fixed in checkpoint 2). The automatic-context staging heuristics
  (`staged_alloc_rd_*`, `skip_free_*`) exist to patch over this
  direct-execution model and remain the highest-risk area.
- `%fork ... %join_detach` when detected synchronously executes the
  fork body inline (vthread.cc of_FORK); interaction with `$finish`
  inside such bodies previously stalled callf drains (Phase 64 fix).

## 6. Event-trigger lifetime and waiter registration

- Named-event triggers wake `@(event)` waiters but a concurrently
  queued `wait (e.triggered)` can miss the trigger (gap **G08**,
  VERIFIED-FAILS): `.triggered` does not implement the LRM
  time-slot-persistent property (1800-2017 15.5.3); there is no
  slot-scoped trigger state cleared at slot end.
- Nonblocking event trigger `->>` is unimplemented (gap G51).

## 7. VPI/DPI callback regions

- Mapped: cbAtStartOfSimTime→`start`, cbReadWriteSynch→`rwsync`,
  cbReadOnlySynch→`rosync`, cbNextSimTime→`vpiNextSimTime()` at time
  advance, cbAfterDelay→generic events.
- cbNBASynch and post-NBA callbacks have no distinct home. DPI blocking
  tasks execute on the calling thread (no suspension region concept).

## 8. End-of-slot / end-of-simulation

- Slot teardown: `run_rosync` + thread deletion, then the slot is
  freed. End of simulation: event loop exits when `sched_list` empties
  or `schedule_finish()`; then final blocks (`schedule_final_list`),
  `signals_revert`, `vpiPostsim`. `$finish` abandons remaining events
  (schedule_finished flag checked in opcode loops — the Phase 64 bug
  showed opcode-level drains must re-check it).

## 9. Invariants / debug support present

- `IVL_SAME_TIME_LIMIT` zero-time-spin watchdog, `IVL_TIME_TRACE_NS`
  time tracing, `vthread_dump_live_threads` on quiesce/watchdog,
  `IVL_CTX_TRACE` automatic-context tracing, `IVL_SCHED_DUMP_THREADS`.
- No region-transition assertions yet; no per-event region tagging.

## 10. Litmus tests (durable regressions added)

`tests/m6_sched_litmus_test.sv`: (a) blocking-then-NBA read ordering
within a slot, (b) #0 inactive ordering across initial blocks,
(c) `$strobe` (rosync) observes post-NBA values while `$display`
(active) observes pre-NBA values. These characterize CURRENT behavior
per LRM-required outcomes and must stay green through any scheduler
restructuring.

## Remediation priorities (for M6 implementation, in order)

1. **DONE 2026-07-14**: region tagging on events + trace hook +
   transition invariant.  Every `event_s` now carries an
   `event_queue_t region` stamped by `schedule_event_` /
   `schedule_event_push_`; `region_enter_` records the region being
   drained and (under `IVL_REGION_TRACE=1`) prints
   `REGION @ <time> ps <region>: <event>` as each event runs.  Because
   the tag travels with the event, an event promoted wholesale into the
   `active` queue (from Inactive or a reactive region) still reports its
   TRUE region — making the wholesale-promotion approximation from item
   2 directly observable.  `region_check_schedule_` enforces the one
   unambiguous LRM region-transition invariant (4.4.2.10: a Postponed /
   read-only ROSync event may only create ROSync or thread-reap work);
   it warns by default and aborts under `IVL_REGION_ASSERT=1` (audit
   point 9: illegal-transition assertions, previously ABSENT).  Verified
   trace order Active→Inactive→NBA→ROSync with `$display` observing
   pre-NBA and `$strobe` post-NBA.  Test:
   `tests/m6_region_trace/run_region_trace.sh`.
2. **DONE 2026-07-12**: Reactive/Re-Inactive/Re-NBA queues added and
   program-block processes routed there (per-thread reactive flag from
   the vpiProgram scope chain, inherited by spawned children; wake
   chains partitioned by region in vthread_schedule_list; program #0
   and NBAs land in Re-Inactive/Re-NBA).  The two elaborate.cc
   compile-progress warnings are retired.  Known approximation: the
   wholesale queue-promotion model (as with inactive/nbassign) means
   Active-region events created DURING reactive execution drain in the
   same promoted queue rather than strictly before the remaining
   reactive events; exact region-priority popping is item 1's tagging
   work.  Test: `tests/m6_reactive_region_test.sv`.
3. Add slot-persistent `event.triggered` state (fixes G08) — 15.5.3.
   **DONE 2026-07-12** (see gap audit G08).
4. **DONE 2026-07-14**: Preponed + Observed regions added.
   `SEQ_PREPONED` drains at slot entry (as a sibling of the Start
   queue, before Active — IEEE 4.4.2.1 sampling); `SEQ_OBSERVED` is
   promoted into `active` after NBA and before the reactive set (IEEE
   4.4.2.4 concurrent-assertion evaluation).  Scheduling entry points
   `schedule_at_preponed` / `schedule_at_observed` exist for the future
   SVA/clocking engines (no consumers yet — this is the foundation).
   Region enum/tag/trace/leftover-check all extended.  Ordering proven
   by the `IVL_REGION_SELFTEST` injection (reverse-order insert drains
   Preponed→Active→NBA→Observed→Reactive→Re-NBA→RWSync→ROSync) in
   `tests/m6_region_trace/run_region_trace.sh`.  Known limitation:
   Preponed fires only on a time advance (like the Start queue), which
   matches the intended consumer (clock edges are always at delay>0).
5. Replace callf synchronous-drain assumptions with an explicit
   scheduled-call protocol (retiring the staged-context heuristics) —
   the largest, riskiest item; requires characterization tests first.
   **2026-07-14 (started)**: characterization suite landed
   (`tests/m6_sync_call_characterization_test.sv`, 15 checks pinning
   return values, recursion, chained/nested calls, output/ref args,
   class-method builder chains, expression context, fork interaction,
   zero-time completion) and the full protocol design +
   incremental-migration plan recorded in
   `m6_scheduled_call_protocol.md`.  The protocol swap itself is the
   scoped follow-up (5 gated steps, the default-flip getting its own
   checkpoint).  The design also calls out the UVM-identifier limit
   special-casing in `do_callf_void` as the clearest remaining
   manifesto-principle-5 violation to delete once the scheduled path is
   clean.
