# Session log — 2026-07-14: M6 item 5 step 2 — scheduled-call path behind a flag

Engineering target: migration step 2 of the scheduled-call protocol —
introduce the scheduled path behind `IVL_SCHED_CALLF` (default OFF) and
prove it on the characterization suite, without disturbing the default
synchronous behavior.

## Root-cause understanding confirmed

A `%callf/<type>` opcode already pushes the return placeholder onto the
CALLER's stack, then `do_callf_void` runs the callee.  The callee's
`%ret` walks up (`get_func`) to the return-slot owner and pokes the
value into `fun_thr->parent` — i.e. the caller's stack.  The dispatch
loop advances `thr->pc` BEFORE running an opcode and pauses the thread
when an opcode returns false.  Together these mean a scheduled call is
sound: suspend the caller at `%callf` (PC already past it), run the
callee under the scheduler, let its `%ret` fill the caller's frozen
stack slot, and resume the caller after `%end`.

## Implementation (`vvp/vthread.cc`)

- `sched_callf_enabled_()` — env gate for `IVL_SCHED_CALLF`, cached.
- In `do_callf_void`, after the callee frame + automatic context are set
  up and the child is linked as the caller's sole child, a scheduled
  branch: mark the callee `i_am_in_function` + `delay_delete`, set the
  caller `i_am_joining`, drop the synchronous-recursion bookkeeping
  (`callf_scope_stack`/`callf_depth`, since the callee unwinds through
  the scheduler not this C++ frame), `schedule_vthread(child, 0, true)`
  (front of Active = run next, preserving zero-time call semantics), and
  return false to suspend the caller.  `schedule_vthread` owns
  `is_scheduled`, so it is no longer pre-set on the scheduled path (the
  original pre-set tripped `vthread_mark_scheduled`'s
  `is_scheduled == 0` assert — the first bug found and fixed).
- Callee completion reuses the EXISTING join machinery unchanged: on
  `%end`, `of_END` sees `parent->i_am_joining` and calls
  `resume_joining_parent_` -> `do_join`, which mirrors output/ref args
  (`mirror_automatic_call_outputs_if_needed_`), reconciles the automatic
  context, and reaps the callee.

Flag OFF the added branch is skipped and the assignment order around it
is byte-identical to before, so the synchronous model is untouched.

## Verified

- Characterization suite `tests/m6_sync_call_characterization_test.sv`
  (15 checks): PASS with flag OFF **and** with `IVL_SCHED_CALLF=1` —
  return values, recursion, function-calls-function chains, output/ref
  write-back, void side effects, chained class-method builder,
  automatic locals across recursion, expression context, deep
  recursion, and a call inside a fork child all hold under the scheduled
  protocol.
- Informational: `vif_smoke` (a UVM test) also PASSes under the flag
  with zero UVM errors — a promising signal that step-3/4 parity is
  within reach, though the full battery under the flag is deferred to
  those steps.
- Flag-OFF regression battery: recorded in the checkpoint commit
  message (default path unchanged).

## Known follow-ups (steps 3-5)

- `resume_joining_parent_` still resumes an `i_am_in_function` caller
  synchronously (`vthread_run(parent)`); a nested scheduled call
  therefore unwinds partly synchronously.  Correct, but to be made fully
  async in step 3.
- Steps 3-4: bring the scheduled path to full focused-M6 + UVM-subset
  parity under the flag, then flip the default (its own checkpoint).
- Step 5: delete the synchronous drain loops, the per-callsite/edge/
  scope/depth limits, and the UVM-identifier special-casing.

## Regression evidence

Recorded in the checkpoint commit message (flag OFF = default).
