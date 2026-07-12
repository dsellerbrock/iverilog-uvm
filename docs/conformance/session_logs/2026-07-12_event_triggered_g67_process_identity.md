# Session log — 2026-07-12: event.triggered (G08) fallout → G67 root cause

Engineering target: land IEEE 1800-2017 15.5.3 `event.triggered` (G08,
scheduler audit remediation item 3) and resolve the two UVM regressions
(`vif_smoke`, `vif_smoke_v2`) it exposed.

## Timeline of evidence

1. **G08 implementation** (commit `ef35d4b`, merged to main via PR #67):
   - `elab_expr.cc`: `e.triggered` lowered to
     `NetESFunc("$ivl_event_method$triggered")` with a `NetEEvent` parm
     (was `make_const_0(1)` — a silent miscompile that made
     `wait (e.triggered)` block forever and `if (e.triggered)` dead code).
   - `elaborate.cc` `elaborate_wait`: collects `$ivl_event_method$triggered`
     nodes from the wait expression and adds their events to the
     `NetEvWait` (event sensitivity, not nexus sensitivity); compile-progress
     fallbacks now gate on "no nexus sources AND no trigger events".
   - `tgt-vvp/eval_vec4.c`: draws `%evtest E_<event>`.
   - `vvp`: new `%evtest` opcode (of_EVTEST) reads
     `vvp_named_event::triggered_now()`; both `_sa`/`_aa` recv paths stamp
     `note_triggered()` (slot-persistent per 15.5.3).
   - Probes: racing `@(e)` + `wait (e.triggered)` both wake (hits=2); a
     same-slot late waiter falls through; next slot reads false. Also
     verified for class-property events (`uvm_event::wait_ptrigger` shape).
   - Permanent tests: `tests/m6_event_triggered_test.sv` (PASS),
     `tests/m6_sched_litmus_test.sv` (PASS).

2. **Regression**: UVM suite 112 passed / 2 failed — `vif_smoke`,
   `vif_smoke_v2`, both `UVM_FATAL [PH_TIMEOUT] ... @ 9200`. Reproduced
   deterministically with `-DUVM_NO_DPI` (as the suite compiles).

3. **Semantic innocence of G08 established by bisection**:
   - Forcing `%evtest` to constant false (pre-G08 semantics) at runtime:
     still hangs → runtime semantics exonerated.
   - Reverting only the `elab_expr.cc` lowering: passes. Structural diff of
     the two compiled images: the ONLY difference is the 4-opcode
     `if (m_event.triggered) return;` prologue of never-called
     `uvm_event_base::wait_ptrigger`.
   - Replacing `%evtest` with `%pushi` in the failing image: still hangs.
   - Padding the passing image with 4 no-op opcodes at the same spot:
     passes (not code-address shift).
   - Changing ONE operand string (`%disable/flow S_<wait_ptrigger-scope>` →
     `S_<wait_trigger-scope>`) in otherwise byte-identical images flips
     hang/pass. Outcome deterministic across runs and with ASLR disabled →
     uninitialized-memory / allocation-layout dependence, not a race.

4. **Runtime forensics** (IVL_STEP_TRACE, IVL_OBJ_ALIAS_TRACE,
   IVL_MUTATE_TRACE, custom of_PROCESS_SELF/of_PROCESS_KILL tracing):
   - Failing run: driver picks up the last item (`get_next_item`), then the
     whole driver chain goes silent; sequence blocks forever in
     `uvm_sequencer_base::wait_for_item_done`'s `wait (...)`.
   - Kill census: failing run has one extra `%process/kill` with
     `self_kill=1` executed under `uvm_task_phase.execute.$unm_blk_1905`.
   - `process::self()` trace: a phase-process thread showed
     `is_fork_v_child=1` (its twin for another component correctly showed
     0) and resolved `process::self()` to an ANCESTOR thread; UVM stored
     that aliased handle in `phase.m_phase_proc`, and a later legitimate
     phase kill destroyed sibling phase processes — including the driver's
     `run_phase`, mid-handshake.

5. **Root cause (G67)**: `vthread_new` initializes every thread flag except
   `is_fork_v_child`. The malloc'd bitfield inherits heap garbage;
   `logical_process_thread_()` walks up through threads flagged
   `is_callf_child || is_fork_v_child`, so any fork...join_none thread
   landing on dirty memory reports its ancestor's process identity. Which
   thread structs land on dirty memory depends on the entire prior
   allocation history — hence flipping with a 4-opcode codegen change, a
   single label string, or nothing at all.

6. **Fix**: `thr->is_fork_v_child = 0;` in `vthread_new` (vvp/vthread.cc).
   Verified: the previously-failing compiled image (byte-identical, no
   recompile) passes on the fixed runtime; vif_smoke/vif_smoke_v2 pass in
   both DPI modes; all G08 probes and m6 tests still pass.

## Permanent tests added

- `tests/m6_process_identity_test.sv`: fork...join_none watcher is its own
  process (`process::self()` inside the block must not alias the caller's
  process) and `kill()` of the watcher must not kill the calling chain —
  the `uvm_sequencer_param_base::m_safe_select_item` shape, plus a hang
  watchdog.

## Manifesto compliance notes

- No UVM sources modified; no UVM-identifier special cases.
- G08 removed a silent compile-progress miscompile (const-0) and replaced
  it with the correct implementation; the wait fallbacks now trigger only
  when there are neither nexus sources nor trigger events.
- The G67 regression was reduced to evidence at each layer (compiled-image
  bisection → opcode substitution → runtime process-identity tracing)
  before the one-line fix; the fix addresses the defect, not the symptom.
- All diagnostic instrumentation used during the investigation was
  temporary and is NOT part of the committed change.

## Regression evidence (this checkpoint)

- UVM suite: see uvm_fix.log (expected 115/115 with the new test).
- ivtest: expected byte-identical to baseline (vvp fix affects only
  thread-struct initialization; %evtest/G08 already baseline-verified).
- Reduced probes: g08a/b/c PASS, class-event c1/c2/c3 PASS, g67/g67b PASS,
  m6_process_identity PASS.
