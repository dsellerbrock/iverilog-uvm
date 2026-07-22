# Icarus Verilog IEEE 1800 / UVM Conformance Manifesto

## Purpose

This document is the governing implementation and conformance plan for the `dsellerbrock/iverilog-uvm` fork.

Its goals are:

1. Run the unmodified Accellera UVM reference implementation with correct language and runtime semantics.
2. Expand Icarus Verilog toward broad, measurable IEEE 1800-2017 conformance.
3. Track IEEE 1800-2023 separately as a delta.
4. Eliminate silent miscompiles.
5. Make every support claim evidence-based and falsifiable.

This document is the implementation Bible.

Passing UVM is valuable evidence. It is not proof of full IEEE 1800 conformance.

A milestone is not complete because unsupported corners are documented. A milestone is complete only when its defined scope is implemented, tested, and free of known in-scope gaps.

---

## Strict honesty policy

The project must distinguish exactly between:

- **COMPLETE** — all defined milestone scope is implemented and validated.
- **SUBSET COMPLETE** — a named subset is complete, while broader scope remains open.
- **PARTIAL** — useful implementation exists, but meaningful in-scope functionality remains missing.
- **DIAGNOSED** — unsupported behavior is rejected explicitly and safely.
- **OPEN** — implementation work remains.
- **PROVISIONAL** — evidence is strong but an adversarial truth audit is still required.

Never use `CLOSED` or `FULL` merely because UVM passes, a representative test passes, unsupported forms emit `sorry`, a recorded-corners ledger exists, no silent miscompile is currently known, or the parser accepts the construct.

A loud diagnostic is better than a silent miscompile, but it is still unsupported functionality.

---

## Normative sources

Use sources in this order:

1. IEEE 1800-2017.
2. IEEE 1800-2023 for explicitly tracked delta work.
3. The unmodified Accellera UVM reference implementation.
4. Reduced pure-SystemVerilog reproducers.
5. Existing regression evidence.
6. Differential simulator behavior as supporting evidence only.

Never invent clause semantics from memory.

For each feature, identify the relevant clause and subclause; record syntax, semantics, typing, scheduling, VPI/DPI implications; and add positive, negative, and interaction tests where applicable.

---

## Core engineering principles

### 1. Fix the simulator, not UVM

When UVM exposes a failure:

1. preserve the original UVM failure;
2. reduce it to pure SystemVerilog;
3. identify the real compiler/runtime defect;
4. implement the general language behavior;
5. preserve the reduced test;
6. rerun unmodified UVM.

Do not add identifier-based UVM special cases.

### 2. Eliminate silent miscompiles first

Priority order:

1. silent wrong behavior;
2. compiler crashes and assertions;
3. runtime corruption;
4. scheduler races;
5. known UVM semantic blockers;
6. loud unsupported features;
7. rare syntax completeness.

Unsupported behavior must be implemented correctly, rejected explicitly, or intentionally lowered with documented standards-justified semantics.

### 3. Parsing is not support

A feature is supported only when all relevant layers work: preprocessing, parsing, name resolution, typing, elaboration, lowering, code generation, runtime, scheduling, VPI/DPI where applicable, and durable tests.

### 4. Prefer architecture over patch accumulation

Repeated failures involving type reconstruction, parameterized classes, aggregate lvalues, method dispatch, event scheduling, assertion execution, or container access must trigger architectural fixes rather than local workarounds.

### 5. Preserve working behavior through characterization tests

Do not rewrite large subsystems blindly. Characterize, test, migrate incrementally, and remove legacy paths only when equivalent behavior exists.

---

## Architectural programs

### Semantic type and IR remediation

The long-term goal is a consistent semantic type representation across name resolution, elaboration, and lowering.

It must preserve exact type, signedness, packed width, unpacked dimensions, two-state/four-state identity, class specialization, enum identity, lvalue/rvalue category, aggregate layout, constant-expression status, and source location.

Required work:

- inventory AST, type, expression, netlist, and elaboration node families;
- identify where type information is lost;
- remove duplicate downstream type reconstruction;
- define typed expression and typed lvalue interfaces;
- define ownership/lifetime rules;
- preserve specialization through variables, properties, locals, formals, returns, and containers;
- make unsupported semantic shapes explicit.

Do not attempt an all-at-once rewrite.

### Scheduler remediation

Maintain an inventory mapping every scheduling path to runtime API, queue, IEEE region, and permanent test.

Cover Active, Inactive, NBA, Observed, Reactive, Re-Inactive, Re-NBA, Postponed, program scheduling, assertion sampling/evaluation, clocking sampling/driving, named events, nonblocking event triggers, VPI callbacks, DPI task suspension/resumption, end-of-step cleanup, and finalization.

Do not claim scheduler completion until region ownership is documented and race-sensitive litmus tests cover all major paths.

### Aggregate and container model

Unify behavior for static arrays, dynamic arrays, queues, associative arrays, packed/unpacked structs and unions, nested aggregates, and strings where appropriate.

Shared operations should cover indexing, slicing, iteration, resizing, copying, comparison, sorting, reduction, locator methods, assignment compatibility, aggregate layout, VPI, and DPI.

### Runtime class identity

Runtime class objects should preserve concrete class type, base type, specialization identity, property descriptors, virtual method identity, cast relationships, factory-visible type names, and VPI-visible metadata.

---

# Current milestone truth status

## M0 — Reproducible baseline

**Status: COMPLETE**

Maintain clean builds, canonical regressions, UVM, negative tests, VPI, cross-platform CI, and baseline comparison procedures.

## M1A — Typed receiver expressions and chained dispatch

**Status: COMPLETE**

## M1B — Specialization and aggregate typing fidelity

**Status: PARTIAL**

- [x] Fix member access on type-parameter-typed output/ref formals.
      *(Verified resolved 2026-07-21 — see the P1 entry; pinned by
      `sv_typeparam_formal_member`.)*
- [~] Audit specialization through variables, properties, locals, arrays,
      returns, and formals. *(Audited 2026-07-21: specialization is
      preserved through locals, properties, fixed/queue/assoc arrays of
      specialized handles, output/ref formals, function returns, nested
      parameterization, parameterized inheritance + virtual dispatch, and
      per-specialization statics — all correct. The audit uncovered and
      fixed a compiler crash unrelated to specialization: a method call on
      a constant-indexed element of a static unpacked array of class
      handles (`arr[0].method()`) fed a folded-constant index to the
      variable-index normalize path, aborting ivl on a
      `canonical_expr` assertion (`elab_expr.cc`; test
      `sv_array_handle_const_index_method`). Two deeper defects remain
      OPEN, see below.)*
- [~] Reprobe specialization inside nested aggregates. *(2026-07-21:
      defect (a) RESOLVED, (b) OPEN. (a) The struct-member-of-array-element
      symptom generalized to: member access on an element of a static
      unpacked array or a plain dynamic array of an UNPACKED struct is not
      correctly lowered — writes drop, reads return garbage (queues,
      associative arrays, packed structs and scalar unpacked structs all
      work, as they store each element as an object or a flat vector). Full
      support is a large storage/codegen effort disproportionate to the
      (rare, non-UVM) usage, so per the honesty policy the silent
      miscompile is now a loud `sorry` at both the l-value (`elab_lval.cc`)
      and r-value (`elab_expr.cc check_for_struct_members`) sites, gated on
      the container being `netuarray_t` / plain `netdarray_t` (not
      `netqueue_t`). CE test `sv_ustruct_array_member_ce`. A sibling of
      defect (a), the WHOLE-element write `arr[i] = <expr>` (no member
      select), was first found to crash the same way and was briefly gated
      with a `sorry` — then ROOT-CAUSED and FIXED (2026-07-21o). The bug was
      pure codegen: `show_stmt_assign_object` (`tgt-vvp/stmt_assign.c`)
      diverted ANY assignment-pattern r-value to `draw_array_pattern`, which
      is the WHOLE-ARRAY distributor — it ignores the l-value word index and
      read the struct's fields `'{a,b}` as successive array *elements*
      (`arr[0]=a; arr[1]=b`), calling `draw_eval_object` on a plain integer
      and emitting `%null`. The fix only calls `draw_array_pattern` when the
      l-value has NO word index (a true whole-array assign); a per-element
      pattern (`ivl_lval_idx != 0`) now falls through to the same
      build-the-object + `%store/obja` path the scalar `s = '{...}` and the
      element-copy/struct-var cases already use. So `arr[i] = '{...}`, a
      struct-variable assign, and an element-to-element copy all work now,
      and member READS of an assigned element read back correctly. Positive
      test `sv_ustruct_array_element` (the earlier CE test was removed). Note
      the sibling still open: a member WRITE `arr[i].field = x` to an element
      that was never whole-assigned drops silently because static object-array
      elements are not auto-constructed (each element starts null); that path
      stays gated by the member-access `sorry` above until element
      auto-construction lands. While reducing
      (a) a second real crash surfaced and was fixed: the TASK-method path
      (`arr[0].method();` as a statement — a void method with a constant
      index) hit the same `canonical_expr` assertion as the earlier
      function-expression fix; `elaborate_root_indexed_method_target_expr_`
      now uses the constant normalize path too (test
      `sv_array_handle_const_index_method` extended to cover it).
      (b) `$cast` between two different specializations of the same
      parameterized class (Box#(byte) vs Box#(shortint)) wrongly succeeded —
      RESOLVED 2026-07-21. The run-time cast check
      (`vpi/sys_sv_class.cc class_cast_compatible_`) keyed types on the bare
      class name (`vpiName`), which is `"Box"` for every specialization, so
      distinct specializations aliased. Root cause: the compiler emits a
      separate `.class` record for the same specialization in each
      referencing scope, each with a different `scope_path`, so neither the
      class-type pointer nor `vpiFullName` is invariant per specialization —
      but the dispatch prefix (`m._ivl_0` vs `m._ivl_1`) is. The fix exposes
      the dispatch prefix through `vpiDefName` (`vvp/class_type.cc`) and keys
      the cast on it, so matching specializations still cast and mismatched
      ones are rejected; ordinary inheritance up/down casts are unchanged.
      Test `sv_cast_param_class_specialization`.)*
- [ ] Remove remaining compile-progress fallbacks caused by lost specialization.
- [ ] Add adversarial parameterized-UVM regressions.

## M1C — Canonical semantic IR migration

**Status: OPEN**

- [ ] Inventory legacy semantic representations.
- [ ] Define canonical type descriptor boundaries.
- [ ] Define typed lvalue interfaces.
- [ ] Document semantic ownership/lifetime rules.
- [ ] Identify compiler paths bypassing canonical typing.
- [ ] Migrate high-risk expression and aggregate families incrementally.

## M2 — UVM factory, config, callbacks, and field automation

**Status: COMPLETE FOR DEFINED MILESTONE SCOPE**

Future failures belong to the underlying language/runtime subsystem unless the UVM mechanism itself is incorrect.

## M3A — Common class-based UVM constraint solving

**Status: COMPLETE FOR COMMON UVM FLOWS**

## M3B — Full clause-18 randomization

**Status: PARTIAL**

- [x] Implement `std::randomize(var...)`. *(Done 2026-07-21: the scope
      (non-class) expression form now lowers to `$ivl_std_randomize`, whose
      VPI implementation writes an unconstrained random value into each
      integral variable argument and returns 1 — previously it returned
      success without assigning anything (silent no-randomization). The
      statement form with a with-clause keeps its range/enum/retry
      constraint lowering; a with-clause in expression context randomizes
      the variables but does not enforce the constraints (loud warning).
      Test `sv_std_randomize_scope`.)*
- [x] Implement `randcase`. *(Done 2026-07-21: `PRandCase` lowers to
      procedural code — each weight evaluated once, summed, one
      `$urandom_range(sum-1)` draw, cumulative-threshold branch select; a
      zero total weight executes no branch. Was a `sorry`. Test
      `sv_randcase`.)*
- [ ] Implement `randsequence`.
- [x] Implement `unique {}` constraints. *(Done 2026-07-21: `unique {vars,
      arr, ...}` (IEEE 1800-2017 18.5.5) parses (`PEUnique`) and the
      constraint-IR emitter expands un-indexed rand array operands to their
      elements and emits pairwise `(ne ...)` terms to the Z3 backend.
      Handles scalar-variable lists and whole-array operands. Was a syntax
      error. Test `sv_constraint_unique`.)*
- [ ] Implement `disable soft`.
- [ ] Reaudit `rand_mode` and `constraint_mode` combinations.
- [ ] Add seed-stability and failed-randomization state tests.

## M4A — Core container runtime and known silent value-loss fixes

**Status: COMPLETE FOR CURRENT CORE**

## M4B — Aggregate/container completion

**Status: PARTIAL**

- [x] Support wildcard associative-array index declarations where required. *(Done 2026-07-21: `type name[*];` (IEEE 1800-2017 7.8.1) now parses. The lexer folds `[*` into one token (`K_LBSTAR`, shared with the SVA consecutive-repetition opener) whose comment wrongly assumed `[*` had no other use, so `variable_dimension` gained a `K_LBSTAR ']'` rule that builds an associative array with a placeholder integral index type (assoc arrays share one queue-compat runtime form regardless of declared index type). Integral keys, exists/delete/size/foreach all work. Test `sv_assoc_wildcard_index`.)*
- [x] Correct `%p` formatting for integral aggregates. *(Done 2026-07-21:
      rewrote the `%p` handler as a recursive assignment-pattern formatter
      (`format_p_value` in `vpi/sys_display.c`). Queues, dynamic arrays,
      fixed unpacked arrays and associative arrays now print
      `'{v0, v1, ...}` (assoc as `'{key:val, ...}`) with integral elements
      in decimal, reals via `%g`, strings quoted; empty containers print
      `'{}`. The old handler asked every element for `vpiStringVal`, so
      integral elements came out as raw ASCII bytes (99 → `'c'`) or empty
      (unimplemented `get_word(string)` for queue/darray elements). Also
      fixed assoc key rendering (vector keys were the raw byte encoding —
      now decimal, `vvp_assoc.h peek_entry`) and queue element type
      detection for real/string queues (`vpi_darray.cc get_word_value`).
      Test `sv_display_p_aggregates`. Element signedness fixed 2026-07-21:
      signed integral dynamic-array/queue/assoc elements now render in
      signed decimal (`-1`, not `4294967295`). The declared element
      signedness is carried on the `.var/darray` / `.var/queue` declaration
      (a `'+'` marker emitted by codegen, parsed via a `signed_opt`
      grammar flag, stored on `__vpiDarrayVar`, and used by
      `get_word_value`) — the VPI-handle route, which is one declaration
      site rather than the 10+ lazy runtime construction sites. Test
      `sv_display_p_signed`. Two cosmetic refinements remain (deferred as
      disproportionate to a display-only payoff): a multi-dimensional
      unpacked array prints flat (`'{1,2,3,4,5,6}`) rather than nested
      because iverilog flattens unpacked dims and VPI exposes no per-dim
      geometry for the element iterator; and a packed struct prints as one
      decimal rather than a `'{member:val}` pattern.)*
- [x] Fix nested packed-struct array literal compiler crash. *(Done
      2026-07-21: module-scope nested literals work on all probed shapes;
      the remaining defect was a class-property whole-array pattern store
      that silently zero-filled — fixed via `draw_prop_array_pattern`
      (`%store/prop/v/i` per element). Test `sv_class_prop_array_pattern`.
      Sibling real/string class-property array storage is a separate,
      deeper defect: issue #100.)*
- [x] Fix unpacked-array typedef return plus assignment-pattern compiler
      crash. *(2026-07-21: IMPLEMENTED (issue #99). A function may return an
      unpacked array; the return signal is emitted as a real array
      (`elab_sig.cc` splits the unpacked dims; `vvp_scope.c` no longer
      skips it), the body stores the result elements into it, and the call
      site invokes the function like a void function then copies the words
      out into the target array/slice (`draw_ufunc_uarray`). Automatic and
      static functions; int/real/string elements; multi-dimensional
      returns; slice targets. Shape mismatches are a clean elaboration
      error. Tests `sv_uarray_func_return` (positive) and
      `sv_uarray_func_return_fail` (CE, now a shape mismatch). Note:
      unpacked arrays in automatic scopes use static storage in vvp, so a
      recursive function returning an array through concurrent activations
      shares that storage — a pre-existing vvp property, not introduced
      here.)*
- [x] Fix class-property unpacked arrays of `real`/`string` (were a silent
      miscompile — every element stored to one slot). *(Done 2026-07-21:
      array-capable real/string cobject property storage + indexed opcodes
      `%store/prop/{r,str}/i` / `%prop/{r,str}/i`. Test
      `sv_class_prop_real_string_array`. Issue #100.)*
- [ ] Continue adversarial nested-container testing.
- [ ] Reaudit nested property read/write/method shapes after future typing changes.

## M5 — Interfaces and modports

**Status: PARTIAL — AUDITED 2026-07-21**

- [x] Audit full modport member access restrictions. *(2026-07-21:
      direction enforcement (writing an input member through a modport)
      was already implemented and errors cleanly. Member VISIBILITY was
      NOT enforced — writing a member the modport does not list compiled
      silently; now a clean error (`elab_lval.cc`, alongside the direction
      check; import/export-listed subroutines stay accessible). CE test
      `sv_modport_visibility_fail`. READ-side visibility now enforced too
      (2026-07-21n): reading an interface member not listed in the modport
      through the expression path (`x = p.hidden;`) used to compile
      silently and then ICE in synthesis ("Failed to synthesize
      expression"); it is now the same clean error, added in
      `PEIdent::elaborate_expr_class_member_` (`elab_expr.cc`), visibility
      only — reading a listed input OR output member stays legal. CE test
      `sv_modport_read_visibility_fail`.)*
- [x] Revalidate output/inout imported task copy-back. *(2026-07-21:
      works — single-attached-instance binding with an explicit warning
      that dynamic multi-instance copy-back is not implemented; verified
      accumulating state + output arg across two calls.)*
- [x] Remove or justify hard dispatch limits such as `VIF_DISPATCH_MAX`.
      *(2026-07-21: REMOVED. The fixed 64-instance cap silently dropped
      instances beyond it, so virtual calls through handles bound to
      instances 65+ quietly did nothing. Collection is now dynamically
      sized. Test `sv_vif_dispatch_many` (72 instances). The same
      investigation found and fixed a broader silent miscompile: the
      receiver index of `arr[i].method()` on a STATIC array of class
      handles or virtual interfaces was dropped in BOTH the task-method
      and function-method elaboration paths — every call dispatched
      through element 0. Test `sv_class_array_method_dispatch`.)*
- [x] Verify per-specialization interface typing. *(2026-07-21: verified —
      two specializations of a parameterized interface keep distinct
      widths/parameter values, both data and methods.)*
- [~] Stress parameterized virtual-interface arrays. *(2026-07-21:
      constant-index vif-array binding (`vp[2] = pins[2]`) and
      element-indexed method dispatch work; binding with a RUNTIME index
      (`vp[i] = pins[i]` in a loop) fails at elaboration — "Scope index
      expression is not constant" — because interface-instance selection
      is a scope operation. Needs a runtime instance-dispatch table.)*
- [~] Audit bare module-scope virtual-interface declarations. *(2026-07-21:
      a `virtual pin_if vp;` declaration at compilation-unit ($unit) scope
      is a parse error. Module-scope and class-property declarations
      work.)*
- [x] Fix change-sensitivity on interface-member (object-property) reads.
      *(Found 2026-07-21n, FIXED 2026-07-21p. An edge/`@*` sensitivity whose
      source is an interface-member read did not fire when that member
      changed: interfaces are modeled as class objects, so the member read
      lowers to a property access whose value-change event was built on the
      object HANDLE (which never changes after binding), not on the
      underlying interface signal. `assign p.b = p.a;` and `always @(p.a)
      p.b = p.a;` (p an interface port) left `b` stuck at its T0 value.
      The fix reuses the existing virtual-interface edge machinery
      (`%wait/vif/anyedge`, which dynamically resolves a vif object's
      per-signal edge functor at run time) that previously handled only the
      NESTED `obj.vif_handle.sig` UVM pattern. A DIRECT interface-port member
      `p.sig` — where the port handle IS the vif object, with no intermediate
      vif property — is now detected in the explicit `@()` event path
      (`elaborate.cc`) and encoded as a direct vif probe (sentinel
      `vif_N == UINT_MAX`); codegen (`tgt-vvp/vvp_process.c`) emits
      `%load/obj <port>; %wait/vif/<edge> <M>` with no `%prop/obj` extraction.
      The vif-member continuous-assign lowering
      (`elaborate_vif_member_assign_`) now sensitizes the re-apply process on
      `@(<rhs>)` instead of `@*`, so a single interface-member r-value routes
      through the direct probe. A real-net r-value (`assign inf.req =
      rnd[0];`, `ivltests/sv_interface.v`) is unaffected — `@(rnd[0])`
      sensitizes on the real net exactly as `@*` did. Test
      `sv_interface_member_sensitivity` (continuous-assign + explicit-`@`,
      both edges). Extended 2026-07-22 to a SINGLE interface member wrapped
      in operators (`assign p.out = ~p.in;`, `p.a[i]`, `sel ? p.a : ...`):
      `collect_iface_member_props_` recurses the event expression, and when
      exactly one interface member and no ordinary-net read is present a
      direct vif probe is built in the general (post-`synthesize`) event path
      too — previously such expressions failed to synthesize (class property)
      and the event was dropped to a T0-only trigger. Finally extended
      2026-07-22 to MULTI-member and MIXED r-values (`p.a & p.c`,
      `p.a & module_net`): `%wait/vif` waits on a single signal per event, so
      the vif-member continuous-assign lowering now FANS OUT into one
      `always @(read) (lhs = rhs)` process per distinct signal read in the
      r-value (`collect_pform_reads_` + a `symbol_search`/dedup filter),
      each re-applying the whole assignment when its own source changes — an
      interface member routes through the vif probe, an ordinary net through a
      normal probe. This exposed a second bug: `NetEvent::find_similar_event`
      merged the per-member events because their probe nets (the shared vif
      HANDLE) matched, collapsing both to one signal's `vif_M`; a
      `vif_probes_match_` guard now blocks merging events whose vif signal
      identity (edge kind / `vif_N` / `vif_M` / `vif_pre_N`) differs. All
      forms (bare / indexed / operator-wrapped / multi-member / mixed, both
      edges) covered by `sv_interface_member_sensitivity`. UVM 209/0/0
      (nested-vif clocking unaffected).)*

## M6A — Core scheduler/runtime repairs

**Status: SUBSET COMPLETE**

## M6B — Scheduler conformance

**Status: PARTIAL**

Completed: construct-level region inventory, event-region litmus tests, program completion behavior, `$exit`, nonblocking event trigger fixes, and callf trampoline architecture.

Remaining:

- [x] Implement per-instance class event storage and triggering. *(Done
      2026-07-21: per-object `vvp_named_event_dyn` storage + `%evt/obj` /
      `%wait/obj` opcodes; `->obj.ev` / `@(obj.ev)` are per-instance for
      obj.ev, a.b.ev, arr[i].ev, and assoc `m_events[k].ev`. Also fixed a
      pre-existing fork double-reap crash exposed by the change.)*
- [x] Implement correct `process.status()` transitions. *(2026-07-21:
      SUSPENDED reported for suspended processes; FINISHED / KILLED /
      WAITING(event/join) / RUNNING already worked. Final refinement done
      2026-07-21: a process parked on a `#delay` reported RUNNING, not
      WAITING — the delay reschedules the thread on the timing wheel
      (`is_scheduled` stays set) with no distinguishing flag. New
      `i_am_delaying` vthread flag (set in `of_DELAY`/`of_DELAYX`, cleared
      when the thread resumes in `vthread_run`) drives the WAITING
      transition. All six states verified in
      `sv_process_status_transitions`.)*
- [x] Implement `process::suspend()` and `process::resume()`. *(Done
      2026-07-21: `%process/suspend` / `%process/resume` opcodes; a
      suspended thread is skipped by vthread_run with the pending wake
      recorded, so resume() continues exactly where it left off — including
      an event that fired while suspended (deferred, not lost).
      Self-suspend parks immediately. Test `sv_process_suspend_resume`.)*
- [ ] Complete post-NBA VPI callback-region support.
- [ ] Define scheduling for time-consuming DPI imports.
- [ ] Complete assertion attempt lifecycle scheduling.
- [ ] Keep the scheduler inventory synchronized with every scheduler change.

## M7 — Accellera UVM qualification

**Status: COMPLETE FOR THE HARNESS SUITE — full UVM regression 209/209, 0 skipped**

The RAL front door and major UVM subsystems execute correctly, and the
bundled UVM regression suite passes with zero skips.

- [x] Fix per-instance class events so UVM objection events do not cross-wake between instances. *(Done 2026-07-21; the shared-event cross-wake is gone.)*
- [x] Fix the `m7_objection_stress` run-phase completion blocker. *(Done
      2026-07-21. The real cause was NOT objection count propagation (that
      is correct) but a runtime defect: a reference to `this` from a nested
      detached (join_none) fork body resolved to null for later iterations,
      so the phase hopper's per-phase `drop_objection` saw a null `this`,
      `get_objection()` returned null, and the drop silently no-op'd on the
      null handle. Fixed in `vvp/vthread.cc`
      (`vthread_get_rd_context_item_scoped` single-live-activation fallback).
      Issue #103. Tests `sv_this_nested_detached_fork` +
      `m7_objection_stress_test` (un-skipped, now PASS).)*
- [x] Re-enable and verify full extract/check/report/final phase execution.
      *(m7 now ends at t=80 with all post-run phases executing.)*
- [x] Run full RAL, sequence, objection, TLM, callback, and phasing stress
      suites. *(UVM regression 209 passed / 0 failed / 0 skipped.)*

Note: the harness suite is green, but per the truth rules this is
"COMPLETE for the probed suite," not a proof of standards-complete UVM.

## M8 — Clocking blocks and program scheduling

**Status: PROVISIONAL COMPLETE**

- [ ] Reprobe edge-qualified skew forms.
- [ ] Reprobe real/string/aggregate clockvars.
- [ ] Stress parameterized virtual-interface clocking.
- [ ] Stress clocking + program + assertion + VPI ordering.
- [ ] Verify every clause-14 subfeature has a disposition.

## M9A — Core SVA token-pipeline engine

**Status: COMPLETE**

## M9B — Fixed-shape sequence algebra

**Status: SUBSTANTIAL / PARTIAL**

## M9C — Temporal property operators

**Status: PARTIAL**

## M9D — Advanced SVA semantics and automaton engine

**Status: OPEN**

- [ ] Implement goto repetition.
- [ ] Implement nonconsecutive repetition.
- [ ] Implement local sequence variables.
- [ ] Implement `.matched`.
- [ ] Complete `.triggered`.
- [ ] Implement `expect`.
- [ ] Support richer sequence operands for temporal operators.
- [ ] Generalize variable-length `intersect` and `within`.
- [ ] Implement multiclock semantics.
- [ ] Implement full assertion attempt lifecycle.
- [ ] Implement procedural concurrent assertion forms.
- [ ] Implement checker constructs or create a dedicated checker milestone.
- [ ] Introduce an automaton/state-machine engine where linear lowering is semantically insufficient.

## M10A — Core DPI imports and packed vectors

**Status: COMPLETE FOR CURRENT SUBSET**

## M10B/M10C — DPI completion

**Status: PARTIAL**

- [ ] Implement multidimensional open arrays.
- [ ] Implement DPI exports / C-to-SystemVerilog calls.
- [ ] Implement real context semantics.
- [ ] Verify complete scope API behavior.
- [ ] Verify `chandle` ABI representation.
- [ ] Support time-consuming imported tasks.
- [ ] Add C→SV→C reentrancy tests.
- [ ] Run real DPI regressions on Linux, macOS, and Windows.

## M11A — Class-embedded functional coverage core

**Status: COMPLETE**

## M11B — Full clause-19 declaration and sampling surface

**Status: PARTIAL**

- [ ] Implement package-scope covergroups.
- [ ] Implement module/interface-scope covergroups.
- [ ] Complete sampling-event forms.
- [ ] Complete `with function sample` formal semantics.
- [ ] Audit arbitrary coverpoint expressions.
- [ ] Audit all `option` and `type_option` properties.
- [ ] Define durable coverage serialization/interchange goals.
- [ ] Build adversarial cross and transition coverage tests.

## M12A — Core SystemVerilog VPI object model

**Status: SUBSTANTIAL**

## M12B/M12C — VPI completion

**Status: PARTIAL**

- [ ] Implement assertion start/step/disable lifecycle callbacks.
- [ ] Populate meaningful `s_vpi_attempt_info`.
- [ ] Complete bit-select force/release.
- [ ] Complete associative-array element writes.
- [ ] Complete nested class-member traversal.
- [ ] Expose complete modport direction/access metadata.
- [ ] Complete covergroup drill-down handles.
- [ ] Define and test VPI object lifetime/free behavior.

## M13A — Implemented long-tail core

**Status: SUBSET COMPLETE**

Includes substantial support for module/type bind, let, specify paths, common timing checks, rare net/strength constructs, and preprocessing corner cases.

## M13B — Remaining long-tail support

**Status: PARTIAL**

- [ ] Implement bind to a specific instance path.
- [ ] Implement bind target-instance lists.
- [ ] Implement actual `config` semantics and library mapping.
- [ ] Implement `trireg` charge semantics.
- [ ] Implement `$nochange`.
- [ ] Implement `$timeskew`.
- [ ] Implement `$fullskew`.
- [ ] Implement timing-check edge descriptor lists.
- [ ] Implement timestamp/timecheck conditions.
- [ ] Implement `pulsestyle`.
- [ ] Implement `showcancelled`.

## M14A — Initial IEEE 1800-2017 clause disposition

**Status: COMPLETE**

This means the matrix exists and every top-level clause has a disposition. It does not mean the language is fully conformant.

## M14B — Exhaustive subclause conformance campaign

**Status: OPEN**

- [ ] Correct stale `FULL` labels where in-clause features remain unsupported.
- [ ] Re-evaluate every `FULL` row containing a documented corner.
- [ ] Downgrade clauses 19, 31, 35, and 36 until known missing features are implemented.
- [ ] Add subclause-level evidence.
- [ ] Link matrix rows directly to permanent tests.
- [ ] Repeat silent-miscompile hunting with adversarial and generated tests.
- [ ] Maintain a zero-known-silent-gap policy.

## M15 — IEEE 1800-2023 delta

**Status: OPEN**

Do not begin broad M15 work until P0/P1 correctness blockers and the major reopened 2017 gaps are under control.

---

# Highest-priority correctness backlog

## P0 — Per-instance class events

**Status: IMPLEMENTED (2026-07-21).** Non-static class `event` properties
now have per-instance runtime storage; the shared-event cross-wake is gone.

- [x] Store event identity per runtime object instance.
- [x] Add dynamic class-property event wait operations.
- [x] Add dynamic class-property event trigger operations (blocking + NB).
- [ ] Verify event assignment/alias semantics. *(Not implemented; UVM does not use it.)*
- [x] Verify multiple waiters.
- [~] Re-run UVM objection and phase-hopper stress tests. *(Objection
      cross-wake fixed and front-door stress passes; the phase-hopper
      stress still blocks on the separate `phase_hopper_objection` count-
      propagation gap — see M7.)*

Known follow-up: `obj.ev.triggered` still lowers through the shared-event
path (the `%evtest/obj` opcode exists but isn't wired into expression
elaboration yet).

## P0 — `$unit` class timescale semantics

**Status: FIXED (2026-07-21).** `$time`/`$realtime` in a `$unit`-scope class
method now scale to the active `` `timescale `` (they used to walk out to
`$unit` = 1 s and give 0 for a stored `$time`). Fix: `sys_time_scope()` in
`vpi/sys_time.c` stops the scope walk before crossing into a package/`$unit`.

- [x] Apply active timescale/timeunit semantics to `$unit` class declarations.
- [x] Verify `$time`.
- [x] Verify `$realtime`.
- [x] Verify delays inside class methods.
- [x] Verify nested calls and package interaction. *(module / `$unit` / package
      classes all covered; ivtest `sv_unit_class_timescale`.)*

## P1 — Remaining type-parameter formal member access

- [x] Fix member access on output/ref formals typed by type parameters.
      *(Verified RESOLVED 2026-07-21: the original "Variable t does not
      have a field named ..." defect (m7 stress findings 2026-07-18) no
      longer reproduces on any probed shape — it was fixed by the
      intervening M1B typing and virtual-output copy-back work. Probed:
      output-T and ref-T deref in parameterized methods; T inherited from
      a specialized base; deref after a nested parameterized call; virtual
      dispatch through a parameterized base handle with subclass-member
      deref; nested t.sub.inner deref in output tasks and ref functions.)*
- [x] Add pure-language and UVM-shaped tests. *(Test
      `sv_typeparam_formal_member` pins all six shapes; UVM-shaped
      coverage via `m1b_typeparam_member_call_test` and
      `m1b_virtual_output_copyback_test` in the UVM suite.)*

## P1 — Known compiler crashes

- [x] Fix nested literal into array of packed structs. *(2026-07-21:
      module-scope works; class-property whole-array pattern store no
      longer zero-fills. Test `sv_class_prop_array_pattern`.)*
- [x] Fix function return of unpacked-array typedef with assignment
      pattern. *(2026-07-21: fully implemented — see the M4B entry (issue
      #99). Positive test `sv_uarray_func_return`; the CE test now pins the
      shape-mismatch diagnostic.)*
- [~] Search for adjacent assertion/abort paths and add negative hardening
      tests. *(Ongoing: added CE hardening test for the uarray-return
      abort; more assert/abort sweeps pending.)*

---

# Conformance matrix truth rules

A clause may be marked `FULL` only if all in-scope subfeatures are implemented, no known in-clause unsupported feature remains, no known compiler crash remains, no known silent miscompile remains, positive and negative tests exist, and interaction behavior has been tested where applicable.

If a clause has known unsupported functionality, use `PARTIAL` or `DIAGNOSED`.

`FULL on probed constructs` is not equivalent to standards-complete.

---

# Definition of done

A feature is complete only when:

1. governing clause identified;
2. syntax implemented;
3. illegal forms diagnosed;
4. names resolve correctly;
5. exact types preserved;
6. elaboration correct;
7. runtime correct;
8. scheduling correct where applicable;
9. VPI defined where applicable;
10. DPI defined where applicable;
11. positive tests pass;
12. negative tests pass;
13. interaction tests pass;
14. UVM regression passes where applicable;
15. broader regression remains baseline-clean;
16. conformance documentation updated;
17. no known in-scope corner remains hidden behind a completion label;
18. work is committed and pushed.

---

# Execution order

Unless new evidence changes priorities:

1. Fix per-instance class events.
2. Fix `$unit` class timescale semantics.
3. Fix known compiler crashes.
4. Finish M1B type-fidelity residuals.
5. Reaudit M5.
6. Continue M6 scheduler/process completion.
7. Finish M9D SVA architecture.
8. Finish M10 DPI.
9. Finish M11 coverage declaration/sampling surface.
10. Finish M12 VPI.
11. Finish M13 long-tail support.
12. Perform M14B subclause conformance campaign.
13. Begin M15 IEEE 1800-2023 delta.

Always prioritize newly discovered silent miscompiles or crashes above this order.

---

# Final principle

The goal is not to produce the appearance of completeness.

The goal is measurable conformance.

Every support claim must be tied to a standard clause, real implementation, permanent tests, regression evidence, and honest remaining limitations.

When reality and milestone wording disagree, change the milestone wording.
