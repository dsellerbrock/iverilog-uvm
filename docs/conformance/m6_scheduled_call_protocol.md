# M6 item 5 — Scheduled-call protocol design

Scheduler-remediation item 5 (the last M6 item): replace the `%callf`
synchronous-drain model with an explicit scheduled-call protocol.  This
document records the current model, its defects, the invariants that
must be preserved, and the target design.  It is the plan for a scoped
follow-up; the durable characterization suite
(`tests/m6_sync_call_characterization_test.sv`) is landed first so the
restructuring has a safety net (manifesto: "Preserve working behavior
through characterization tests, then replace implicit ordering
incrementally"; audit point 10: "Produce scheduler litmus tests before
restructuring code").

## 1. Current model (`vvp/vthread.cc` `do_callf_void`)

A `%callf/<type>` opcode creates a child thread for the called
function/task and runs it **synchronously inside the caller's opcode
dispatch** — the caller's `of_CALLF_*` does not return to the scheduler
until the callee has run to completion.  `do_callf_void` drives the
child with three back-to-back loops:

1. a resume loop (budget `IVL_CALLF_SYNC_RESUME_LIMIT`, default 65536)
   that re-runs the child while it stays scheduled and unblocked;
2. a drain loop (budget `IVL_CALLF_SYNC_DRAIN_LIMIT`, default 65536)
   that walks the child's descendant tree, resumes joining parents, and
   drives any runnable descendant — flattening nested synchronous calls;
3. a second short resume loop (budget 256).

Around those loops sit the risk-bearing heuristics the audit flagged:

- **Context staging** (`staged_alloc_rd_context` / `skip_free_context`
  and `sanitize_thread_contexts_` / `ensure_write_context_`): patch the
  automatic read/write context that the direct-execution model
  otherwise corrupts across the call boundary.
- **Liveness backstops**: per-callsite, per-edge, per-scope, and depth
  counters (`callf_self_site_invocations`, `callf_edge_invocations`,
  `callf_scope_invocations`, `callf_depth`) that abandon the call with a
  "compile-progress return fallback" once a limit is hit — masking
  zero-time loops rather than diagnosing them.
- **UVM-identifier special-casing** (manifesto principle 5 violation):
  the limits above are raised by name for `uvm_object.new`,
  `uvm_root.m_uvm_get_root`, `uvm_coreservice_t.get(_root)`,
  `uvm_report_object.uvm_report_info`,
  `uvm_cmdline_processor.get_arg_value`.  These are the single clearest
  remaining example of the identifier-based compiler/runtime branching
  the manifesto wants eliminated.

## 2. Defects already root-caused here (audit §4/5)

- Chunk-boundary `%fork`/`%join_detach` misparse (Phase 64).
- "callf child did not end synchronously" join-wait fallback (G48,
  currently a suppressed diagnostic).
- Same-scope returned-frame shadowing (fixed in an earlier checkpoint
  but the fix lives inside the staging heuristics).

All three are symptoms of one root cause: a subroutine call is modelled
as *direct nested execution* instead of *a scheduled thread the caller
waits on*.

## 3. Invariants to preserve (characterization suite)

`tests/m6_sync_call_characterization_test.sv` pins the observable
contract any protocol must keep (all pass on the current build):

1. a function returns its value to the caller in the same time step;
2. recursion allocates a fresh automatic frame per call;
3. a function may call another function synchronously (chains);
4. `output`/`ref` arguments are written back before the caller resumes;
5. a void function's side effects are visible after the call returns;
6. chained class-method calls on a returned handle (`a.set(x).get()`);
7. automatic locals survive across recursive descent;
8. calls in expression/condition context;
9. moderately deep recursion completes with no time advance;
10. a call inside a `fork` child returns synchronously to that child.

Zero-time completion (no `#`-delay is introduced by a call) is itself an
invariant: subroutine calls do not advance simulation time.

## 4. Target protocol

Model a blocking subroutine call as a **scheduled callee + suspended
caller**, resolved without leaving the scheduler's control:

1. `%callf` allocates the callee frame/context, links it as the caller's
   child, marks the caller *blocked-on-callee*, and hands the callee to
   the scheduler as an Active-region thread (no time advance).
2. The callee runs under the normal run loop.  A nested call repeats the
   protocol — depth is bounded by the actual call graph, tracked by the
   scheduler, not by a synchronous C++ recursion on the vvp stack.
3. On callee completion, its return value/`output`/`ref` writes land,
   and the scheduler resumes the blocked caller (the existing
   join/`resume_joining_parent_` machinery generalizes to this).
4. Automatic context lifetime becomes explicit at the two protocol
   edges (allocate-on-enter, free-on-resume), retiring
   `staged_alloc_rd_context` / `skip_free_context`.
5. A genuine zero-time-loop is caught by the scheduler's existing
   same-time watchdog (`IVL_SAME_TIME_LIMIT`) — one uniform mechanism —
   letting all the per-callsite/edge/scope counters and every
   UVM-name special-case be deleted.

Region interaction: a subroutine call keeps the caller's region (a call
from an Active-region thread stays Active; from a reactive/program
thread stays reactive).  The region tag added in item 1 already travels
with the thread, so the trace will show call/return staying in-region.

## 5. Migration plan (incremental, each a regression-clean checkpoint)

1. **DONE** — characterization suite + this design.
2. **DONE 2026-07-14** — scheduled-call path landed behind
   `IVL_SCHED_CALLF` (default OFF).  In `do_callf_void`, once the callee
   frame and its automatic context are set up, the scheduled branch
   schedules the callee to the front of the Active region and returns
   false to suspend the caller; the callee's `%ret` fills the caller's
   return slot (the caller is frozen, so its stack is stable) and its
   `%end` resumes the caller through the existing
   `of_END` -> `resume_joining_parent_` -> `do_join` join machinery
   (which already mirrors output/ref args and reaps callf children).
   The whole characterization suite (all 15 checks incl. recursion,
   chained methods, output/ref args, fork interaction) passes under the
   flag; `vif_smoke` (a UVM test) also passes under the flag with zero
   errors — a promising parity signal.  Flag OFF is byte-identical to
   the synchronous model.
3. Bring the scheduled path to parity on the full focused-M6 + a
   representative UVM subset under the flag; characterize any divergence
   (the `resume_joining_parent_` `i_am_in_function` branch still resumes
   a nested caller synchronously — acceptable for correctness, to be
   made fully async here).
4. Flip the default to the scheduled path; run the full UVM + ivtest
   battery; keep the synchronous path as a one-release fallback.
5. Delete `do_callf_void`'s synchronous drain loops and all the
   staging/limit/UVM-name heuristics once the scheduled path is
   baseline-clean.

Each step gates on UVM 125/125 + ivtest failure-name parity before the
next; step 4 is the highest-risk flip and gets its own checkpoint.
