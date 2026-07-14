# Session log — 2026-07-14: M6 item 4 — Preponed + Observed regions

Engineering target: the second scheduler-remediation priority from the
audit — add the Preponed (sampling) and Observed (concurrent-assertion
evaluation) regions as the SVA/clocking foundation.  Builds directly on
item 1's region tagging (same session, prior checkpoint).

## What was added (`vvp/schedule.cc`, `vvp/schedule.h`)

- **Two regions in the enum and pipeline**: `SEQ_PREPONED` inserted
  after `SEQ_START` (before Active), `SEQ_OBSERVED` after `SEQ_NBASSIGN`
  (before the reactive set).  New `preponed` / `observed` queues on
  `event_time_s`, new `schedule_event_` switch cases, `region_name_`
  entries, and the `run_rosync` leftover-events check extended.
- **Drain placement (IEEE 1800-2017 4.4.2)**:
  - Preponed (4.4.2.1) drains in the time-advance block as a sibling of
    the Start queue — at slot entry, before any Active-region change,
    so sampled values reflect the previous slot.  Like Start, it fires
    only on a time advance; the intended consumers (clock edges) are
    always at delay>0, so this matches.
  - Observed (4.4.2.4) is promoted into `active` after `nbassign` and
    before `reactive`, mirroring the existing inactive/nbassign/reactive
    promotion chain.
- **Scheduling entry points**: `schedule_at_preponed` /
  `schedule_at_observed` (header-exported) give the future SVA and
  clocking engines (M8/M9) a place to hook sampling and evaluation.
  There are no consumers yet — this is deliberately the foundation, not
  an SVA implementation.
- **Ordering self-test** (`region_selftest_`, env `IVL_REGION_SELFTEST=1`,
  one-shot): injects a labeled no-op into each delay-permitting region in
  REVERSE order at time +1, so an `IVL_REGION_TRACE` run proves the
  scheduler drains them in forward IEEE order.  Env-gated: zero effect on
  normal runs.

## Verified

- `tests/m6_region_trace/run_region_trace.sh` extended with a second
  part asserting the self-test order is exactly
  `Preponed Active NBA Observed Reactive Re-NBA RWSync ROSync` — proving
  both new regions land in the correct IEEE positions despite reverse
  insertion.  PASS.
- Focused M6 SV suites (litmus, reactive_region, event_triggered,
  process_identity): all PASS — the new regions are inert when unused,
  so existing slot behavior is unchanged.

## Design notes / limitations

- Inactive and Re-Inactive assert delay==0 (they are #0 regions), so the
  self-test omits them; their ordering is covered behaviorally by
  `tests/m6_sched_litmus_test.sv`.
- Preponed fires only on a time advance (as noted).  A Preponed event
  scheduled for the current slot from within it would not drain — but
  that is not a real use case (sampling is always for a future edge).

## Remaining M6 tail

- Item 5: replace the `%callf` synchronous-drain assumption with an
  explicit scheduled-call protocol (largest/riskiest; needs
  characterization tests first).  This is the next and final M6 item.

## Regression evidence

Recorded in the checkpoint commit message.
