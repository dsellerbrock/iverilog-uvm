# Session log — 2026-07-14: M6 item 5 rearchitecture increment 2 — trampolined callf

Engineering target: increment 2 of the step-5 rearchitecture — replace
the C++-recursive synchronous call with a **trampoline** that runs the
callee within the caller's `vthread_run` loop, preserving function-call
atomicity (the invariant the scheduled path violated) without consuming
C++ stack per SV call depth.  Behind `IVL_TRAMPOLINE_CALLF` (default
OFF).

## Mechanism (`vvp/vthread.cc`)

- New per-thread flag `is_trampoline_child`; module globals
  `trampoline_call_stack` (callers to return to) and
  `trampoline_switch_to` (next frame for the loop); a
  `TRAMPOLINE_MAX_DEPTH` runaway backstop.
- **Call**: `do_callf_void`'s trampoline branch (reusing the existing
  child setup: context bind, arg/return-slot plumbing, parent link)
  pushes the caller onto `trampoline_call_stack`, sets
  `trampoline_switch_to = child`, and returns — no recursive
  `vthread_run`.
- **Loop switch**: the `vthread_run` inner loop, after each opcode,
  switches `thr` to `trampoline_switch_to` (the callee) and continues in
  the same C++ frame.
- **Return**: the callee ends via *any* end opcode.  Functions actually
  terminate with `%disable/flow` (→ `do_disable`, sets `i_have_ended`),
  not `%end` — so the switch-back is keyed on
  `rc==false && is_trampoline_child && i_have_ended` in the loop, not on
  a specific opcode.  It pops the caller, switches `thr` back, and reaps
  the callee via `do_join` (which mirrors output/ref args and reconciles
  the automatic context).  The return value was already poked into the
  caller's stack by `%ret`.

## Two bugs found and fixed during bring-up

1. Globals declared after `vthread_run` → not in scope; moved above it.
2. First cut intercepted `of_END`, but functions end with
   `%disable/flow`; moved the switch-back into the loop's `rc==false`
   path so it fires for any end opcode.

## Result — the trampoline reaches FULL parity (and keeps atomicity)

Under `IVL_TRAMPOLINE_CALLF=1`:
- `tests/m6_call_atomicity_test.sv`: **PASS** — the invariant the
  scheduled path VIOLATED.  Concurrent calls no longer interleave (the
  callee runs entirely within the caller's execution).
- `tests/m6_sync_call_characterization_test.sv`: PASS (recursion,
  chained methods, output/ref args, fork interaction, expression
  context).
- `pr2053944` / `pr2001162` (the scheduled path's two ivtest failures):
  now correct.
- **UVM suite: 127/127.**
- **ivtest `vvp_reg.pl`: failure names byte-identical to baseline.**
- Recursion depth: 100/500/1000/2000 complete; ~10000 is slow — the
  `do_join` context reconciliation is O(depth), so extreme depth is
  O(depth²).  Still deeper than the synchronous model (capped at 4096);
  a perf follow-up, not a correctness issue.

This makes the trampoline the viable replacement the scheduled path was
not: it preserves atomicity AND removes the C++-stack-per-call-depth
constraint that the depth heuristics exist for.

## Default posture

`IVL_TRAMPOLINE_CALLF` defaults OFF: the synchronous `do_callf_void`
path is unchanged.  The inner-loop additions are a null-check
(`trampoline_switch_to`, never set when off) and an `rc==false` guard
(`is_trampoline_child`, never set when off), so the default hot path is
behavior-identical — confirmed by the default-config battery (evidence
in the checkpoint commit).

## Next

Increment 3: flip the default to the trampoline (its own checkpoint,
the highest-risk change), then delete the three synchronous drain loops
and the automatic-context staging.  Optionally first address the
`do_join` O(depth) reconciliation so deep recursion is linear.
