# M6 item 5 — rearchitecting the synchronous call model (step 5)

The scheduled-call experiment (steps 2-3) established, empirically, that
a Verilog function call **must** execute synchronously within the
calling process: a function is atomic, zero-time, and part of the
caller's statement (IEEE 1800-2017 13.4.3).  Scheduling the callee as a
separate thread and suspending the caller violates that atomicity
(`tests/m6_call_atomicity_test.sv`, ivtest `pr2001162`/`pr2053944`).

That result **redirects step 5**.  The goal was never "replace
synchronous execution" — synchronous execution is correct.  The goal is
to remove the accumulated *cruft* around it: the redundant drain loops,
the four overlapping fallback heuristics, and — the clearest
manifesto-principle-5 violation — the UVM-identifier special-casing.

## 1. What `do_callf_void` actually is

`%callf/*` (functions only; tasks use `%fork`/`%join`) creates a callee
thread and runs it to completion inside the caller's opcode dispatch via
`do_callf_void`.  Because functions are zero-time, the callee always
finishes in the same time step.  Correct in essence; the problem is the
scaffolding.

## 2. The cruft inventory (all in `do_callf_void`)

Four overlapping fallback heuristics, each of which — when its limit is
hit — abandons the call with a "compile-progress return fallback"
(returns a wrong/default value):

| # | mechanism | metric | default | UVM-name raises |
|---|---|---|---|---|
| a | `site_limit` | cumulative self-recursive calls at one callsite | 256 | 64 / 2048 / 16384 / 8192 / 16384 |
| b | `scope_limit` | same scope's count on the callf stack (cycle) | 4096 | 16384 |
| c | `depth_limit` | `callf_depth` for same-scope recursion | 2048 | 16384 / 32768 |
| d | absolute | `callf_depth` (any) | 4096 | — |

Plus two **warning-only** hot counters (edge/scope at 50000; no
fallback) and three synchronous drain loops (resume / descendant-drain /
resume) with their own budgets, and the automatic-context staging
(`staged_alloc_rd_context` / `skip_free_context`).

### Two concrete findings

- **(c) is dead code.**  The same-scope `depth_limit` raises to
  16384/32768 can never take effect: a same-scope recursion passes the
  `depth_limit` test but then hits the unconditional absolute cap (d) at
  `callf_depth > 4096`, which fires first for any `depth_limit > 4096`.
  So the per-name depth raises do nothing; the effective same-scope cap
  is `min(depth_limit, 4096)`.
- **All four are proxies for one real failure mode: C++ stack
  exhaustion.**  Every synchronous call nests a `do_callf_void` C++
  frame, so genuine zero-time infinite recursion overflows the C++
  stack.  The four heuristics are ad-hoc guesses at "too deep"; the
  per-name numbers are tuning for specific UVM recursion patterns that
  exceeded the defaults.

## 3. Target architecture

### 3a. Near term (this increment): one name-agnostic backstop surface

Collapse the per-name special-casing into single generous constants.
The limits become pure runaway backstops (never scope-specific
correctness knobs).  This removes every `strstr("uvm_...")` from the
call path (principle 5) while preserving the effective cap for the
scopes that currently rely on a raised value (each limit is set to the
maximum any name previously granted, so no passing recursion is
truncated earlier).  Dead mechanism (c) is retired in favor of the
single absolute depth cap (d).

### 3b. Medium term: trampolined synchronous call

The reason the depth caps exist at all is the C++-stack recursion.
Replace it with a **trampoline**: when the caller's `vthread_run` loop
hits `%callf`, push the callee frame onto an explicit per-thread call
stack and continue the SAME loop at the callee's entry (no recursive
`vthread_run`); on the callee's `%end`/`%ret`, pop back to the caller.
Atomicity is preserved (no scheduler yield — the callee runs entirely
within the caller's execution, before any sibling active event), and
C++ stack depth is bounded by the loop, not the SV call depth — so the
depth backstops can be replaced by the scheduler's existing single
zero-time watchdog (`IVL_SAME_TIME_LIMIT`).  This also lets the three
drain loops collapse to the natural trampoline loop and retires the
automatic-context staging (context lifetime becomes explicit at the two
trampoline edges).

### 3c. End state: delete the heuristics

Once trampolined, `do_callf_void`'s three drain loops, the four limit
mechanisms, the edge/scope/site maps, and the staged-context helpers all
go, replaced by a single push-frame / run-loop / pop-frame path plus one
general watchdog.  This is the full realization of step 5.

## 4. Increment sequence (each regression-clean)

1. **DONE** — Remove UVM-identifier special-casing: unified
   site/scope/depth limits to name-agnostic constants; retired dead
   mechanism (c).  UVM 127/127 + ivtest baseline-identical.
2. **DONE 2026-07-14** — Trampoline the call (3b) behind
   `IVL_TRAMPOLINE_CALLF` (default OFF).  `%callf` switches the
   `vthread_run` inner loop to the callee frame and back on the callee's
   end (any end opcode — detected by `rc==false && is_trampoline_child
   && i_have_ended`), reaping via `do_join` (output/ref mirroring +
   context reconciliation).  No recursive `vthread_run`, so C++ stack
   depth is bounded by the loop, not the SV call depth.
   **Result**: under the flag, the WHOLE battery reaches parity — UVM
   **127/127** and ivtest failure names **byte-identical** to baseline
   (incl. `pr2001162`/`pr2053944`, which the scheduled path FAILED) —
   and the atomicity suite PASSES (which the scheduled path failed).
   The trampoline is therefore the viable replacement: it preserves
   function-call atomicity AND removes the C++-stack constraint.  Known
   limitation: `do_join`'s automatic-context reconciliation is O(depth),
   so recursion beyond a few thousand frames is slow (O(depth²)) — still
   deeper than the synchronous model's 4096 cap; a perf follow-up.
3. **DONE 2026-07-14** — Flipped the default to the trampoline
   (`IVL_TRAMPOLINE_CALLF=0` selects the legacy synchronous fallback).
   Full default-config battery clean: UVM 127/127, ivtest failure names
   byte-identical to baseline, vpi 85/85, py 284/12.
4. **PARTIAL 2026-07-14** — Deleted the BROKEN scheduled-call path
   (`IVL_SCHED_CALLF` and `schedule_defer_calls_ok`/`sched_main_loop_running`):
   the atomicity finding proved it wrong, so it was dead, incorrect
   code — an unconditional removal.  **Retained** (for one release, per
   the manifesto's fallback rule) the synchronous `do_callf_void` drain
   loops + automatic-context staging + limit maps as the
   `IVL_TRAMPOLINE_CALLF=0` fallback: ~450 lines of battle-tested
   edge-case handling (reaped-child recovery, dynamic-dispatch mirroring)
   that deserve a soak before removal.  Their deletion is the final
   follow-up once the trampoline default has soaked a release.

Each step preserves the atomicity invariant
(`tests/m6_call_atomicity_test.sv`) and the call semantics
(`tests/m6_sync_call_characterization_test.sv`).
