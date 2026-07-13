# Session log — 2026-07-12 (fourth target): Reactive region for programs

Engineering target: M6 scheduler remediation item 2 — schedule
program-block processes in the Reactive region set (IEEE 1800-2017
4.4.2.5 Reactive, 4.4.2.6 Re-Inactive, 4.4.2.7 Re-NBA; clause 24).

## Starting evidence

Reduced probe (module DUT increments a counter with an NBA on posedge;
program samples at the same edge): the program deterministically read
the PRE-NBA value — program threads ran in the Active region, racing
the design.  The compiler carried two standing compile-progress
warnings admitting this ("Program (non-)blocking assignments are not
currently scheduled in the Reactive(-NBA) region").

## Implementation

- **ivl_target API**: new `ivl_scope_program(ivl_scope_t)` — the
  NetScope program flag now crosses into code generators (t-dll.h
  `is_program`, both scope-construction sites, t-dll-api.cc getter).
- **tgt-vvp**: program instance scopes emit `.scope program` (was
  `module`).
- **vvp scope**: new `vpiScopeProgram` (type code `vpiProgram`) parsed
  from the new scope-type string.
- **vvp threads**: `vthread_s::is_reactive_process` (initialized —
  G67's lesson — and set at `vthread_new` by walking the scope parent
  chain for `vpiProgram`); inherited by all spawned children
  (fork/callf/chunk-continuation sites), so tasks and class methods
  called FROM a program execute as program code.  Accessor
  `vthread_is_reactive()` for the scheduler.
- **vvp scheduler** (schedule.cc): three new per-slot queues
  `reactive`, `re_inactive`, `re_nbassign`; enum + schedule_event_
  cases; promotion order per 4.4.2:
  active ← inactive ← nbassign ← reactive ← re-inactive ← re-nba ←
  rwsync (rosync unchanged at slot teardown).  Entry routing:
  `schedule_vthread` and `schedule_inactive` consult the thread's
  reactive flag; the thread NBA entry points
  (`schedule_assign_vector`, both `schedule_assign_array_word`
  overloads) gain a `reactive` parameter passed from the %assign
  opcode family in vthread.cc.  Net/force/propagate scheduling is
  untouched (design semantics).
- **Wake-chain partitioning** (the subtle one): a single edge/event
  functor can hold both design and program waiters in one wake chain;
  `vthread_schedule_list` previously scheduled the whole chain as one
  event in one region.  It now partitions the chain by the reactive
  flag (preserving relative order within each partition) and schedules
  the partitions separately.  Without this, a shared `@(posedge clk)`
  functor dragged program threads into Active (or design threads into
  Reactive) depending on chain order.
- **elaborate.cc**: both program-scheduling warnings and the
  now-unused `lval_not_program_variable` helper removed.

## Known approximation (recorded in the scheduler audit)

The wholesale queue-promotion model (pre-existing for
inactive/nbassign) means Active events created DURING reactive
execution drain in the same promoted queue rather than strictly before
the remaining reactive events.  Exact region-priority event popping is
remediation item 1's region-tagging work.

## Verified orderings (permanent test `tests/m6_reactive_region_test.sv`)

(a) program sampling at a clock edge sees the design's post-NBA state
for that same edge (both edges checked); (b) program #0 (Re-Inactive)
runs before the program's own NBA (Re-NBA); (c) the Re-NBA update is
observable via @(x) within the same slot; (d) a design process
triggered by a program's blocking write runs in Active (iterative
loopback) before the program's next #0 continuation.

## Regression evidence

Recorded in the checkpoint commit message (UVM suite + ivtest run in
this session); all prior m6/g12 focused tests re-verified PASS.
