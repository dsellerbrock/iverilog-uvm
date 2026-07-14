# Session log — 2026-07-14: M6 item 5 step 3 — parity + a fundamental blocker

Engineering target: bring the scheduled-call path (behind
`IVL_SCHED_CALLF`) to full parity under the flag, then flip the default
(step 4) and delete the synchronous heuristics (step 5).  Outcome: step 3
fixed the one UVM divergence, but empirical ivtest parity uncovered a
FUNDAMENTAL atomicity violation that blocks the default flip — the
correct, intended result of gating the flip on parity.

## Step 3a — init/final-phase guard (implemented)

Under `IVL_SCHED_CALLF=1` the only UVM divergence was
`static_init_order_test`.  Root cause: class-static initializers run in
the pre-simulation init phase, drained by a loop that does not process
the active queue; a deferred (scheduled) callee scheduled there never
ran, so `Foo::m_state` stayed 0.  Fix: `schedule_defer_calls_ok()`
(schedule.cc/.h) is true only while the main event loop is draining —
false during the init drain, the final drain, and the read-only rosync
region.  The scheduled callf branch falls back to synchronous execution
when it is false; those phases are inherently sequential, so synchronous
execution is correct there.  Result: **UVM 126/126 under the flag**.

## Step 3b — the parity blocker (found, root-caused, pinned)

The full ivtest corpus under the flag: 134 fail vs 132 baseline — two
NEW divergences, `pr2001162` and `pr2053944`.  Both root-cause to one
defect: **function-call atomicity** (IEEE 1800-2017 13.4.3 — a function
runs as part of the calling process and does not yield).

- `pr2053944` (minimal): two `always @Start` blocks each assign
  `Vi = Copy(i)` with a STATIC function `Copy`.  Default → `1 2`.
  Flag ON → `1 1`: suspending the caller across the call lets both
  invocations interleave, and the static function's single shared return
  storage is cross-contaminated.
- `pr2001162`: a shared `counter` read-modified-written through a
  function in two concurrent tasks; under the flag the increments are
  lost/observed stale because a sibling process runs during the call.

The naive protocol (step 2) suspends the caller and schedules the callee
as a separate thread; between suspend and resume, other active-region
processes run — violating the atomicity a function call must have.  The
step-2 characterization suite missed this because it is single-process.
Pinned by the new `tests/m6_call_atomicity_test.sv` (PASS on the default
synchronous path; FAIL under the flag).

## Decision: steps 4-5 blocked (do NOT flip)

Flipping the default would turn the atomicity violation into silent
miscompiles across any concurrent function-call pattern — a manifesto
principle-4 violation.  So the default stays synchronous
(`IVL_SCHED_CALLF` OFF); the scheduled path stays behind the flag.  This
is the migration plan working as designed: step 4 gates on ivtest
parity, and parity testing caught the flaw before the flip.

### Revised design requirement (next target)

The callee must run to completion WITHOUT yielding the active region:
an inline/coroutine-style scheduler-tracked frame (the caller remains
the running thread; the callee frame is driven to completion before any
sibling active event runs), not a separate scheduled thread the caller
joins on.  This is a larger redesign than suspend-caller and is the next
M6 item-5 engineering target.

## Regression posture

Default is unchanged (flag OFF): the scheduled branch is gated by
`sched_callf_enabled_()`, and the `schedule_defer_calls_ok()` flag is
only read from that gated path, so the default path is byte-identical.
The new atomicity test passes on the default.  Evidence in the
checkpoint commit message.
