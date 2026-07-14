# Session log — 2026-07-14: M6 item 1 — event region tagging

Engineering target: the first scheduler-remediation priority from the
2026-07-12 audit — introduce per-event IEEE 1800-2017 clause-4 region
tagging, a trace hook, and a region-transition invariant.  Items 2
(reactive regions) and 3 (slot-persistent `event.triggered`) were done
earlier; this is the keystone that makes item 2's wholesale-promotion
approximation observable and lays the invariant groundwork for item 4
(Preponed/Observed).

## What was added (`vvp/schedule.cc`)

- **Per-event region tag**: `event_s` gains `event_queue_t region`,
  stamped by `schedule_event_` and `schedule_event_push_`.  The
  `event_queue_e` enum moved above `event_s`; its declaration order IS
  the drain/promotion order (Start, Active, Inactive, NBA, Reactive,
  Re-Inactive, Re-NBA, RWSync, ROSync, DelThread).
- **Trace hook** (`region_enter_`, env `IVL_REGION_TRACE=1`): before
  each event runs, records the region being drained
  (`sched_current_region`) and prints
  `REGION @ <time> ps <region>: <event>`.  Wired into every run site:
  the main active-queue loop, the Start (cbAtStartOfSimTime) drain, and
  the ROSync + DelThread drains in `run_rosync`.  Because the tag rides
  on the event, an event promoted wholesale into the `active` queue
  still prints its TRUE region — e.g. a `#0` continuation prints
  `Inactive`, a program NBA prints `Re-NBA` — exposing exactly the
  promotion approximation the audit flagged for item 2.
- **Transition invariant** (`region_check_schedule_`): enforces the one
  unambiguous LRM rule (4.4.2.10) — a Postponed / read-only ROSync
  event may only schedule further ROSync or thread-reap work.  Warns by
  default (generalizing the old post-hoc string check in `run_rosync`
  into a proactive, tag-based one) and aborts under
  `IVL_REGION_ASSERT=1`.  This is audit point 9 (illegal-transition
  assertions), previously ABSENT.

Design note: the invariant is deliberately narrow.  The design region
loop (Active↔Inactive↔NBA) and the reactive loop legitimately revisit
earlier regions, and RWSync correctly re-promotes into Active, so a
blanket "monotonic region" assertion would false-positive.  Only the
read-only→write transition is unconditionally illegal, so that is the
only hard invariant asserted.  Everything else is left to the trace.

All three mechanisms are env-gated: zero overhead and zero behavior
change in normal runs (the tag is a single enum store per event).

## Verified

- `tests/m6_region_trace/run_region_trace.sh` (new durable regression):
  compiles a design touching Active/Inactive/NBA/Postponed in one slot,
  runs under `IVL_REGION_TRACE=1`, asserts all four region tags appear
  and in stratified order (Inactive before NBA before ROSync).  PASS.
- Trace of a scratch probe shows Active→Inactive→NBA→ROSync with
  `$display` (Active) reading pre-NBA `nb=xx` and `$strobe` (Postponed)
  reading post-NBA `nb=aa` — the region tags match observed values.
- Focused M6 SV suites (litmus, reactive_region, event_triggered,
  process_identity) all PASS.

## Remaining M6 tail

- Item 4: Preponed sampling + Observed evaluation regions (SVA/clocking
  prerequisite, M8/M9).  The region enum + tag + trace now give it a
  place to slot in and an invariant harness to validate against.
- Item 5: replace the `%callf` synchronous-drain assumption with an
  explicit scheduled-call protocol (largest/riskiest; needs
  characterization tests first).

## Regression evidence

Recorded in the checkpoint commit message.
