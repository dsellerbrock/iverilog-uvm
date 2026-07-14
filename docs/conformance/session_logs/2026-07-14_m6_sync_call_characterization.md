# Session log — 2026-07-14: M6 item 5 (started) — synchronous-call characterization

Engineering target: begin the last and riskiest M6 remediation item —
replacing the `%callf` synchronous-drain model with an explicit
scheduled-call protocol.  Per the manifesto ("preserve working behavior
through characterization tests, then replace incrementally") and audit
point 10 ("produce scheduler litmus tests before restructuring code"),
this session lands the characterization safety net and the protocol
design; the swap itself is the scoped follow-up.

## Why characterization-first (not the swap)

`do_callf_void` (vvp/vthread.cc, ~380 lines) runs a called function/task
thread synchronously inside the caller's opcode dispatch, driven by
three budgeted drain loops and surrounded by the audit's highest-risk
heuristics: automatic-context staging (`staged_alloc_rd_context` /
`skip_free_context`), per-callsite/edge/scope/depth liveness backstops,
and — the clearest remaining manifesto-principle-5 violation —
UVM-identifier-specific limit raises (`uvm_object.new`,
`uvm_root.m_uvm_get_root`, `uvm_coreservice_t.get`, …).  Swapping this
for a scheduled protocol touches every subroutine call in the runtime;
it cannot be made regression-clean over 125 UVM + 2961 ivtest passes in
a single checkpoint, so the disciplined move is to lock the invariants
first.

## Delivered

- **`tests/m6_sync_call_characterization_test.sv`** (15 checks): the
  observable contract any protocol must preserve — value return;
  recursion (fresh automatic frame per call); function-calls-function
  chains; output/ref write-back before caller resume; void side
  effects; chained class-method builder (`b.set(9).get()`); automatic
  locals across recursive descent; expression/condition context;
  moderately deep recursion; a call inside a fork child; and zero-time
  completion (a call advances no simulation time).  PASS standalone and
  under the UVM harness.
- **`docs/conformance/m6_scheduled_call_protocol.md`**: the current
  model, the three already-root-caused defects (all one root cause —
  call modelled as direct nested execution rather than a scheduled
  thread the caller waits on), the invariant list, the target protocol
  (schedule the callee as an Active-region thread + suspend the caller,
  resume on completion via the existing join machinery, explicit
  context lifetime at the two protocol edges, one uniform zero-time
  watchdog replacing every per-name counter), and a 5-step incremental
  migration plan where each step gates on UVM + ivtest parity and the
  default-flip gets its own checkpoint.

## Incidental finding (logged, not chased): G70

Running the new suite under the UVM harness surfaced a pre-existing
non-fatal diagnostic — `uvm_component.svh:2490`
`succ[iter].get_parent()` → "not a dynamic array method" (indexed-element
class-method call mis-routed into darray-method dispatch).  Verified
NOT a regression: identical (2×) for the known-passing `vif_smoke`,
present at every 125/125 checkpoint, compile-progress continues so tests
still pass.  Recorded as gap G70 for a future focused elaboration
session.

## Regression note

This checkpoint adds only a test and docs — no compiler/runtime code
changed, so the vvp/iverilog binaries are byte-identical to the item-4
promotion (ivtest/vpi/negative already recorded baseline-identical
there).  The only gate that changes is the UVM suite, which
auto-discovers the new test.  Evidence recorded in the commit message.

## Remaining M6 tail

Item 5 protocol swap (steps 2-5 of the migration plan).  With the
characterization net and design in place, that is now a well-scoped,
lower-risk sequence rather than an open-ended rewrite.
