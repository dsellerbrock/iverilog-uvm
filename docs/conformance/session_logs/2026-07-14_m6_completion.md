# Session log — 2026-07-14: M6 completion — trampoline default + scheduled-path deletion

Engineering target: complete M6 by flipping the callf default to the
trampoline (increment 3) and deleting the broken scheduled-call path
(increment 4).

## Increment 3 — trampoline is the default

`trampoline_callf_enabled_()` now defaults ON; `IVL_TRAMPOLINE_CALLF=0`
selects the legacy synchronous fallback.  The trampoline (increment 2)
had already reached full parity behind the flag; as the default it is
clean across the whole battery:
- UVM **127/127**
- ivtest `vvp_reg.pl` failure names **byte-identical to baseline**
- `vpi_reg.pl` 85/85, `vvp_reg.py` 284/12
- negative 6/6; all focused M6 SV suites incl. `m6_call_atomicity`
- `IVL_TRAMPOLINE_CALLF=0` fallback still passes the focused suites.

So the default subroutine-call model now preserves function-call
atomicity (IEEE 1800-2017 13.4.3) AND bounds C++ stack depth by the
`vthread_run` loop rather than the SV call depth.

## Increment 4 — delete the broken scheduled-call path

The scheduled-call path (`IVL_SCHED_CALLF`) was proven incorrect by the
step-3 atomicity finding (it suspends the caller, so concurrent calls
interleave — `pr2001162`/`pr2053944`).  It was dead, wrong code, so it is
removed unconditionally:
- `sched_callf_enabled_()` and its `do_callf_void` branch (vthread.cc);
- `schedule_defer_calls_ok()` + `sched_main_loop_running` (schedule.cc/.h)
  — these existed only to gate the scheduled path.

## What is retained, and why (manifesto: one-release fallback)

The synchronous `do_callf_void` drain loops, the automatic-context
staging (`staged_alloc_rd_context` / `skip_free_context`), and the
name-agnostic limit maps are kept as the `IVL_TRAMPOLINE_CALLF=0`
fallback.  These are ~450 lines of battle-tested edge-case handling
(reaped-child recovery, dynamic-dispatch output mirroring); with the
trampoline only just made the default, they warrant a soak before
deletion.  SV functions cannot fork (13.4.4), so the descendant-drain
loops cover no legal function case the trampoline misses — but the other
edge-case handling justifies the caution.

## M6 status

All five remediation items delivered their capabilities:
1. region tagging + invariants — DONE
2. reactive region scheduling — DONE
3. slot-persistent `event.triggered` (G08) — DONE
4. Preponed + Observed regions — DONE
5. atomicity-correct call model (trampoline) is the DEFAULT; the broken
   scheduled experiment is removed.

M6's remediation is **functionally complete**: a correct, race-aware
scheduler with region ownership, the SVA/clocking region foundation, and
an atomicity-preserving call model as the default.  The single remaining
item is pure code hygiene — deleting the retained synchronous fallback +
its staging heuristics after a release soak — which changes no behavior
or capability.

## Next

Per the plan, move to the next milestone.  M6's foundation (region
tags/invariants, Preponed/Observed entry points, atomicity-correct
calls) directly unblocks M8 (clocking blocks) and M9 (core SVA engine).

## Regression evidence

Recorded in the checkpoint commit message.
