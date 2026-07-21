# Per-instance class events (P0) — 2026-07-21

## Summary

Implemented **per-instance runtime storage and dynamic wait/trigger for
non-static class `event` properties** (IEEE 1800-2017 §15.5), replacing the
previous behavior where every instance of a class shared one class-scope
`.event` functor. `->obj.ev` now triggers only that object's event and
`@(obj.ev)` waits on the correct object's event, for any object-handle
form: a plain handle, a property chain, an array element, an associative
lookup (`m_events[key].ev`, the UVM objection shape), and the bare member
`this.ev` inside a method.

This closes the **language-level** half of the M7 blocker (the shared
class-event defect). It also *un-masks* a second, independent objection
count-propagation defect in UVM phasing that the shared-event cross-wake
had been hiding — see "Discovered: objection propagation to top" below.

## Root cause (old behavior)

A class `event` property elaborated to a single `NetEvent` in the class
`NetScope`. All references (`->obj.ev`, `@(obj.ev)`) resolved to that one
`NetEvent` → one `vvp_net_t` + `vvp_named_event` functor shared by every
instance. A trigger on one object woke waiters on all objects
(`elab_scope.cc` even emitted a warning to this effect).

## Design

Per-instance event state lives on the runtime object, reusing the existing
named-event wait/trigger machinery:

- **Runtime** (`vvp`): each `vvp_cobject` lazily allocates a `vvp_net_t`
  whose functor is a new `vvp_named_event_dyn` (like `vvp_named_event_sa`
  but with no static VPI `__vpiNamedEvent` handle), keyed by a
  design-global event slot (`vvp_cobject::get_inst_event`,
  `inst_events_`). New opcodes pop an object handle off the object stack
  and act on that object's slot:
    - `%evt/obj <slot>` — blocking trigger (`vvp_send_vec4`, like `%event`)
    - `%evt/obj/nb <slot>,<word>` — nonblocking trigger (`schedule_assign_vector`)
    - `%wait/obj <slot>` — wait (adds thread to the object's wait list)
    - `%evtest/obj <slot>` — `.triggered` query (partial; see limitations)
  The nets are pool-allocated and never individually freed (consistent
  with every other `vvp_net_t`); allocation is lazy so untouched events
  cost nothing.

- **Compiler**: a class-member `NetEvent` is flagged `is_class_event()`
  (in `elab_scope.cc`) and assigned a unique global slot on first use
  (`NetEvent::obj_slot`, `net_event.cc`). New netlist nodes
  `NetEvTrigObj` / `NetEvWaitObj` carry an *object-handle expression* plus
  the slot; new IR statement types `IVL_ST_TRIGGER_OBJ`,
  `IVL_ST_NB_TRIGGER_OBJ`, `IVL_ST_WAIT_OBJ` (accessors
  `ivl_stmt_evobj_expr` / `ivl_stmt_evobj_slot`); `tgt-vvp` draws the
  object with `draw_eval_object` then emits the opcode.
  `elaborate_class_event_target_` (in `elaborate.cc`) elaborates the
  reference prefix as an object expression (via `elab_and_eval` on a
  reconstructed `PEIdent`, or the implicit `this` handle for bare
  members) and resolves the event slot; `PTrigger`, `PNBTrigger`, and
  `PEventStatement::elaborate` route class-member events through it.

The global-unique slot (rather than a per-class index) guarantees base-
and derived-class events never collide within one object's event table.

## Files

- `vvp/event.h`, `vvp/event.cc` — `vvp_named_event_dyn`
- `vvp/vvp_cobject.{h,cc}` — per-instance event net storage
- `vvp/vthread.cc` — `of_EVT_OBJ` / `of_EVT_OBJ_NB` / `of_EVTEST_OBJ` / `of_WAIT_OBJ`
- `vvp/codes.h`, `vvp/compile.cc` — opcode declarations + table rows
- `netlist.h`, `net_event.cc`, `emit.cc`, `design_dump.cc` — netlist nodes + slot
- `ivl_target.h`, `t-dll.h`, `t-dll-api.cc`, `t-dll-proc.cc`, `target.{h,cc}` — IR
- `tgt-vvp/vvp_process.c` — `show_stmt_trigger_obj` / `show_stmt_wait_obj`
- `elaborate.cc`, `elab_scope.cc` — elaboration + class-event flagging

## Tests (all PASS)

- `ivtest/ivltests/sv_class_event_per_instance.v` (new, registered in
  `regress-sv.list`): multi-instance/multi-waiter no cross-wake,
  nonblocking trigger, bare `this.ev` in a method, and an
  associative-array-of-objects element (the UVM objection shape).
- `ivtest/ivltests/sv_class_event_member1.v` (existing) still PASSES.

## Known limitations (honest)

- **`obj.ev.triggered`** on a per-instance event still lowers through the
  old shared-event `.triggered` path and reports the shared functor's
  state (`%evtest/obj` exists but is not yet wired into expression
  elaboration). This was already inconsistent before this change; it is
  not a new regression. Follow-up: route the `.triggered` expression for
  class-member events through `%evtest/obj`.
- **Event assignment/alias** (`event a = b.ev;`) of per-instance events is
  not implemented; UVM does not use it.
- Per-instance event nets are never freed (leak-for-simulation, like all
  vvp nets); bounded for typical use.

## Discovered: objection propagation to top (SEPARATE, pre-existing)

Running `tests/m7_objection_stress_test.sv` against unmodified UVM
2020.3.1 with the fix shows the objection **counters** pass but the run
no longer ends at t=80 — it runs to the UVM 9200 s watchdog. Instrumented
tracing shows why, and it is **not** an event defect:

- The `phase_hopper_objection` (`uvm_phase_hopper`) is *raised on phase
  keys* and the hopper *waits* on `all_dropped` for `uvm_root`.
- Its `all_dropped` callback fires for every component/phase key but is
  **never called for `uvm_root`** — i.e. its integer `m_total_count` for
  the top never reaches 0 under this concurrent workload. That is
  objection *count arithmetic*, untouched by the event change.
- In the shared-event baseline this was masked: a *different* objection
  instance's `all_dropped` trigger (the run objection) cross-woke the
  hopper's waiter (1 trigger → 2 wakes), so the phase advanced anyway
  (prematurely — which is exactly why the post-run function phases were
  documented as never executing).

So the M7 objection blocker is two-layered: (1) shared class events
[fixed here], and (2) `phase_hopper_objection` count-propagation to the
top under concurrent objection traffic [pre-existing, filed separately].
Basic UVM tests (which drop their run objection promptly) are unaffected;
only objection-stress-to-completion scenarios surface layer 2.

## Also discovered (unrelated crash)

`arr[i].property = expr` where `arr` is an unpacked array of class handles
and `i` is a loop variable crashes ivl in `show_stmt_assign_sig_cobject`
→ `ivl_expr_value(NULL)` (tgt-vvp). No events involved. Filed separately.
