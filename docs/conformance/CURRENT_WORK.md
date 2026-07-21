# CURRENT WORK — continuation file

Keep this accurate enough that another session can resume without repeating
the investigation. Update at every meaningful checkpoint.

## State as of 2026-07-21n (Tier-2 M1B type-fidelity fixes — on draft PR #105)

Tier-2 work after the PR #104 merge, all on branch
`claude/ieee1800-uvm-conformance-vp6ic2` (draft PR #105). Every increment:
ivtest sv list Failed=44 (baseline, 0 new / 0 stale by name) + UVM 209/0/0
+ negative suite 49/0. Five fixes:

1. **`%p` signed elements** (`7801f07`): signed integral dynamic-array /
   queue elements printed as unsigned; element signedness now carried on
   the `.var/darray|queue` decl via a `+` marker + `signed_opt` vvp grammar
   flag → `__vpiDarrayVar`. Test `sv_display_p_signed`.
2. **const-index method crash** (`42f5452`, `67ab8dd`): `arr[0].method()`
   (function-expr AND void-statement paths) fed a folded const index to the
   variable-index normalize → `canonical_expr` assert. Both paths now use
   the const-list normalize. Test `sv_array_handle_const_index_method`.
3. **unpacked-struct array element access** — static/darray of UNPACKED
   struct is stored as objects but element access isn't lowered (null /
   garbage, `%p` aborts). Diagnosed loudly, not miscompiled:
   - member `arr[i].field` (`67ab8dd`, defect A) → `sorry` in
     `elab_lval.cc`, CE test `sv_ustruct_array_member_ce`.
   - whole-element `arr[i] = <expr>` on a STATIC array (`1c10fe3`) → `sorry`
     in `elaborate_lval_net_word_`. Boundary: darray/assoc/queue element
     writes and whole-array `arr='{...}` assigns all WORK; only static-array
     per-element is broken. CE test `sv_ustruct_array_element_ce`.
4. **`$cast` specialization identity** (`76e2b2e`, defect B): `$cast`
   between two specializations of one parameterized class (`Box#(byte)` vs
   `Box#(shortint)`) wrongly succeeded — cast keyed on bare `vpiName`
   (`"Box"` for all specializations). Root cause: the compiler re-emits a
   `.class` record per referencing scope with different `scope_path`, so
   neither the class-type pointer nor `vpiFullName` is invariant per
   specialization; the dispatch prefix (`m._ivl_0` vs `m._ivl_1`) is.
   Exposed the dispatch prefix via `vpiDefName` (`vvp/class_type.cc`) and
   keyed the cast on it (`vpi/sys_sv_class.cc`). Inheritance up/down casts
   and null-source casts unaffected. Test
   `sv_cast_param_class_specialization`.

M1B "reprobe specialization inside nested aggregates" is now fully closed
(both member and whole-element unpacked-struct-array corners diagnosed;
specialization identity fixed in $cast). Remaining M1B checklist:
compile-progress fallbacks from lost specialization; adversarial
parameterized-UVM regressions. Next per execution order: reaudit M5, or
hunt the next concrete type-fidelity crash/miscompile.

## State as of 2026-07-21m (Tier-1 frontier sweep COMPLETE — on draft PR #104)

Post-#96-merge Tier-1 work, all on branch
`claude/ieee1800-uvm-conformance-vp6ic2` (draft PR #104). Every increment:
full ivtest default run byte-identical to baseline (44 fails, 0 new / 0
stale by name) + UVM 209/0/0 + negative suite 49/0.

1. **M3B randomization** (commit `00a6e3f`): `randcase` (PRandCase →
   procedural weighted select), `std::randomize(vars)` scope expression
   form (`$ivl_std_randomize` VPI — was a silent no-randomization), and
   `unique {}` constraint (PEUnique → pairwise `(ne)` to Z3). CI fix
   `9532d4b` removed the now-stale `m14_randcase_unsupported` negative test.
2. **`%p` refinements** (audited, documented — see M4B manifesto entry):
   the three residual gaps (signed dynamic-array/queue elements, nested
   multi-dim, packed-struct member form) all need type-descriptor plumbing
   through codegen → vvp assembler → VPI handle, disproportionate to a
   display-only payoff. Fixed arrays and scalars already print correctly.
   No code change; recorded as a justified limitation.
3. **M4B wildcard assoc index** (commit `2356fbe`): `int aa[*]` now parses
   — the lexer folds `[*` into `K_LBSTAR`, so a `variable_dimension:
   K_LBSTAR ']'` rule handles it. Not used by UVM but a clean 7.8.1 gap.
4. **M6B process.status()** (commit `3d4b5f3`): a `#delay`-parked process
   now reports WAITING (new `i_am_delaying` vthread flag), completing the
   status() transitions (RUNNING/WAITING/SUSPENDED/FINISHED/KILLED).

## State as of 2026-07-21l (M3B: randcase + std::randomize + unique {})

Three clause-18 randomization gaps closed (Tier-1 frontier work after the
PR #96 merge):

- **`randcase` (IEEE 1800-2017 18.16)** — was a `sorry`. New `PRandCase`
  pform node (`Statement.h/.cc`, grammar in `parse.y`) lowers at elaboration
  (`elaborate.cc`) to procedural code: each weight is evaluated exactly once
  into a temp, the temps are summed, a single `$urandom_range(sum-1)` draw
  selects a branch by cumulative-threshold compare, and a zero total weight
  runs no branch. Test `sv_randcase` (distribution + once-evaluation +
  zero-weight).
- **`std::randomize(vars)` scope form (18.12)** — the expression form used
  to return success WITHOUT assigning the variables (silent
  no-randomization). It now lowers to a new `$ivl_std_randomize` system
  function (`elab_expr.cc` → `vpi/sys_random.c sys_std_randomize_calltf`)
  that writes an unconstrained random value into each integral variable
  argument and returns 1. A with-clause in *expression* context randomizes
  but does not enforce constraints (loud one-time warning); the *statement*
  with-clause form keeps its existing range/enum/retry lowering. Test
  `sv_std_randomize_scope`.
- **`unique {}` constraint (18.5.5)** — was a syntax error. New `PEUnique`
  pform node (`PExpr.h`, grammar in `parse.y`); the constraint-IR emitter
  (`elaborate.cc pexpr_to_constraint_ir`) expands an un-indexed rand
  unpacked-array operand to its element solver-variables and emits pairwise
  `(ne ...)` terms, so the Z3 backend enforces distinctness. Handles scalar
  lists and whole-array operands. Test `sv_constraint_unique`.

Remaining M3B: `randsequence`, `disable soft`, rand_mode/constraint_mode
reaudit, seed-stability tests.

**Validation:** full ivtest default run byte-identical to baseline
(3074 passed / 44 failed, 0 new / 0 stale by name; +3 new tests); UVM suite
209/0/0.

## State as of 2026-07-21k (P1 type-param formal member access — VERIFIED RESOLVED)

- **P1 "member access on output/ref formals typed by type parameters"
  verified RESOLVED** — the original "Variable t does not have a field
  named ..." failure (m7 stress findings 2026-07-18) no longer reproduces
  on any probed shape; it was fixed by the intervening M1B typing and
  virtual-output copy-back work. Six shapes probed and pinned in new test
  `sv_typeparam_formal_member` (output-T/ref-T deref, inherited-T from a
  specialized base, deref after nested parameterized call, virtual
  dispatch through parameterized base with subclass-member deref, nested
  t.sub.inner deref). No compiler changes needed — test-only increment;
  sv-list gate green (965/44, diffs vs full-run baseline are only the two
  known list-subset artifacts).

## State as of 2026-07-21j (M5 interfaces/modports audit + fixes)

- **M5 truth audit completed; three fixes landed:**
  1. **Static-array method receiver index drop (silent miscompile, the
     big one):** `arr[i].method()` on a static unpacked array of class
     handles OR virtual interfaces dropped the receiver index in BOTH the
     task-method path (`elaborate_root_indexed_method_target_expr_`,
     elaborate.cc — note base_type arrives as the ELEMENT type, so the
     fix keys off the signal's unpacked dimensions) and the
     function-method path (`PECallFunction::elaborate_expr_method_`,
     elab_expr.cc — new static-array root-index application beside the
     existing queue/darray one). Every call dispatched through element 0.
     Test `sv_class_array_method_dispatch`.
  2. **VIF_DISPATCH_MAX removed:** the 64-instance dispatch cap silently
     dropped instances 65+. Dynamic collection now. Test
     `sv_vif_dispatch_many` (72 instances).
  3. **Modport member visibility enforced (write side):** writing an
     interface member the modport does not list compiled silently; now a
     clean error next to the existing direction check. CE test
     `sv_modport_visibility_fail`.
- **Audit results (manifesto M5 updated):** direction enforcement OK;
  imported-task copy-back OK (single-instance, warned); per-
  specialization param-interface typing OK. Remaining gaps recorded:
  read-side modport visibility; runtime-index vif-array BINDING
  (`vp[i] = pins[i]` in a loop → "Scope index expression is not
  constant"); bare $unit-scope `virtual iface v;` declarations parse
  error.
- **Validation:** ivtest + UVM runs pending at checkpoint.

## State as of 2026-07-21i (unpacked-array slice + function return — IMPLEMENTED)

- **Unpacked-array SLICE assignment (`m[0] = '{1,2,3}` for int[2][3]) —
  IMPLEMENTED** (commit `a1c5e39`; was a "sorry"). The l-value carries the
  slice's flat base word + the sub-array type (`NetAssign_::
  set_array_slice`); the pattern elaborates against the sub-array type and
  codegen starts the element store at the base (`array_pattern_base_` at
  the vec4/real/string pattern sites). Constant indices only; variable
  index and non-pattern r-values diagnose cleanly. Test
  `sv_uarray_slice_pattern_assign` (2-D/3-D, real, string, sibling-row
  isolation, whole-array regression guard).
- **Unpacked-array FUNCTION RETURN (issue #99) — IMPLEMENTED** (was a
  graceful sorry, before that an ICE). Root cause chain: (1) the return
  NetNet was built from the raw `netuarray_t` without splitting unpacked
  dims → degenerated to a 1-bit scalar and the body's element stores
  targeted a never-emitted array (`elab_sig.cc` now uses the
  unpacked-dims NetNet ctor); (2) `vvp_scope.c` skipped emitting
  return-value variables — now only for dims==0, so the return array is a
  real `.array`; (3) call sites invoke the function like a void function
  (`draw_ufunc_preamble` forces VOID for dims>0 returns) and
  `draw_ufunc_uarray` copies the words out into the target array/slice
  before the callee frame is freed; (4) `elab_and_eval`'s strict uarray
  compat check learns to shape-check a NetEUFunc against the return
  signal's array type; (5) `PAssign::elaborate` validates count/element
  compatibility (clean error on mismatch). Covers automatic/static,
  int/real/string elements, multi-dim returns, slice targets.
  Tests: `sv_uarray_func_return` (positive), `sv_uarray_func_return_fail`
  (CE, repurposed to shape mismatch — the old sorry no longer fires).
  Limitation (pre-existing vvp property): arrays in automatic scopes are
  static storage, so recursive activations returning arrays share it.
- **Validation:** ivtest + UVM runs pending at checkpoint (slice already
  validated byte-identical / 209-0-0 standalone).

## State as of 2026-07-21h (process::suspend()/resume() — IMPLEMENTED, M6B)

- **`process::suspend()` / `process::resume()` implemented; `status()` now
  reports SUSPENDED.** Commit `a916815`. Elaboration lowers the methods to
  internal system tasks (same pattern as kill/await), codegen emits new
  `%process/suspend` / `%process/resume` opcodes, and the runtime marks the
  owning thread `suspended` so `vthread_run` skips it, recording any
  attempted wake in `suspend_resched`. resume() reschedules if a run was
  pending — an event that fires while suspended is deferred, not lost.
  Self-suspend parks immediately (opcode returns false). Both idempotent.
  Test `sv_process_suspend_resume` (freeze/unfreeze, SUSPENDED status,
  deferred event, idempotency, kill-after-resume).
  Known refinement (recorded in manifesto M6B): a `#delay`-parked process
  reports RUNNING not WAITING (the delay queue marks it `is_scheduled`; a
  dedicated flag would be needed to distinguish).
- **Validation:** ivtest full default run byte-identical to baseline
  (3065/44, 0 new / 0 stale; +1 test); UVM 209/0/0.
- **In progress at checkpoint:** unpacked-array SLICE assignment
  (`m[0] = '{1,2,3}` for int[2][3] — was "sorry") via slice l-values
  (NetAssign_::set_array_slice: flat base word + sub-array type) and
  offset-aware pattern codegen. All shapes (2D/3D int, real, string) pass
  locally; full validation running.

## State as of 2026-07-21g (`%p` aggregate formatting — FIXED, M4B)

- **`%p` (assignment-pattern format) on integral aggregates now correct.**
  Was a silent miscompile: the old handler asked every element for
  `vpiStringVal`, so integral elements rendered as raw ASCII bytes (`99`
  came out as `'c'`) and queue/dynamic-array elements hit an unimplemented
  `get_word(string)` path and printed empty. Observed before:
  `queue='{, }`, `assoc='{c, *}`, `dyn='{, , }`, `scalar=<garbage byte>`.
  Fix: rewrote the handler as a recursive assignment-pattern formatter
  `format_p_value` (`vpi/sys_display.c`) that dispatches on the element's
  natural type — integral → decimal, real → `%g`, string → quoted — and
  recurses into arrays/queues/dynamic/associative arrays. Two supporting
  runtime fixes: (1) associative vector keys were the raw internal byte
  encoding; `peek_entry` now renders them as decimal (`vvp_assoc.h`,
  `vpiName` on an assoc element exposes the key via
  `vpi_darray.cc get_word_str`); (2) real/string **queue** elements were
  mis-detected as vec4 (queue subclasses differ from darray subclasses),
  fixed in `get_word_value`. Also fixed an empty-container buffer overflow
  in the formatter (`'{}` case).
  Now: `queue='{10, 20}`, `assoc='{3:99, 7:42}`, `dyn='{1, 2, 3}`,
  `fix='{5, 6, 7, 8}`, string queue `'{"foo", "bar"}`, real queue
  `'{1.5, 2.25}`, `scalar=195`, empty `'{}`.
  Test `sv_display_p_aggregates`.
  **Known remaining refinements (not silent miscompiles — noted in the
  manifesto M4B item):** signed integral darray/queue elements render
  unsigned (element signedness isn't carried through the container VPI
  path); a packed struct prints as one decimal rather than a
  `'{member:val}` pattern.
- **Validation:** ivtest full default run **byte-identical to baseline**
  (3064 passed / 44 failed, 0 new / 0 stale by name; +2 new tests); UVM
  suite 209/0/0.

## State as of 2026-07-21f (loop-local capture by inline detached fork — FIXED)

- **A loop-body `automatic` captured by an inline detached (join_none/
  join_any) fork now gets the correct per-iteration value inside a class
  method (previously it read the loop's final value).** This closes the
  "Known residual" noted in the 2026-07-21e entry below.
  Root cause: `PBlock::elaborate_scope` (`elab_scope.cc`) collapses an
  automatic begin/fork block into the enclosing task activation frame
  (upstream single-task-frame model), so the loop-body block that declared
  `automatic int idx = i;` shared ONE storage slot across all iterations.
  A detached branch reading `idx` after the iteration completed therefore
  saw only the final value. At module scope the identical block already
  kept a per-entry frame (its static parent is never collapsed), so the two
  contexts disagreed — module gave `4 3 2 1 0`, the class method gave
  `4 4 4 4 4`.
  Fix (IEEE 1800-2017 9.3.2): decline the frame-collapse for a block that
  BOTH declares its own automatic locals AND lexically contains a detached
  fork. Such a block keeps a per-entry `%alloc`/`%free` frame, so each loop
  iteration allocates a fresh copy that the spawned branch retains —
  matching module-scope behaviour. New predicate
  `Statement::contains_detached_fork()` (virtual, overridden in the pform
  container statements) drives the decision; the collapse gate in
  `elab_scope.cc` adds `&& !keeps_frame_for_capture`.
  The outer-automatic / `this` access from the now-own-frame block resolves
  through the same single-live-activation fallback that fixed m7 (#103), so
  the fix composes cleanly with it.
  Test: `sv_loop_local_detached_fork` (class flat loop, class nested
  detached fork, module-scope loop — all in one run).
- **Validation:** ivtest full default run **byte-identical to baseline**
  (3062 passed / 44 failed, 0 new / 0 stale by name); UVM suite **209/0/0**
  (0 skips); the `this`-in-detached-fork and fork-arg-capture ivtests still
  pass.

## State as of 2026-07-21e (M7 GREEN — `this`-in-nested-detached-fork fix)

- **m7_objection_stress_test — FIXED; full UVM suite 209/0/0 (zero skips).**
  Root cause (issue #103, closed): a reference to `this` (or an enclosing
  automatic) from a detached (join_none) fork body nested inside another
  detached fork resolved to **null** for later loop iterations — the forked
  thread's inherited automatic-context chain stopped linking back to the
  owning activation frame across frame reuse. In UVM's phase hopper the
  per-phase `drop_objection` runs in exactly this fork shape, so for
  common.run/common.check `this` went null, `get_objection()` returned null,
  and `drop_objection()` silently no-op'd on the null handle → two
  phase-hopper objections never dropped → run never completed.
  Fix: strictly-additive single-live-activation fallback in
  `vthread_get_rd_context_item_scoped` (`vvp/vthread.cc`) — only on the
  otherwise-null path. Commit `9f3666d`. Tests
  `sv_this_nested_detached_fork` + `m7_objection_stress_test` (un-skipped).
- **Earlier misdiagnoses corrected on the way:** it was NOT objection count
  propagation (traced to uvm_top=0 correctly) and NOT the #102 forked-arg
  capture (real bug, fixed in `9f1909b`, but orthogonal — the hopper uses an
  inline `automatic phase = ph` capture that already worked). #102 handles a
  single-branch `fork task(args); join_none`; this fix handles the implicit
  `this` from a general inline detached fork body.
- **Known residual (RESOLVED 2026-07-21f, see entry above):** a loop-local
  captured by a general inline detached fork body resolved to its last
  value, not the per-iteration value. Now fixed by declining the
  frame-collapse for automatic-local blocks that contain a detached fork.
  `this` was always unaffected (single live activation for a non-recursive
  method).

## State as of 2026-07-21d (P0 silent miscompile: real/string class-property arrays)

- **Class-property unpacked arrays of `real`/`string` — FIXED (was a
  silent miscompile, #100).** The real/string cobject property store/load
  opcodes carried no element index, so every element resolved to one slot:
  element-wise writes clobbered each other and whole-array patterns
  aborted (real) or emptied (string). Now array-capable:
  `property_real`/`property_string` carry an array size (mirroring
  `property_object`/`property_atom`); new opcodes
  `%store/prop/{r,str}/i` and `%prop/{r,str}/i` select the element;
  codegen updated in `stmt_assign.c` (element-wise + whole-array pattern
  via `draw_prop_{real,str}_array_pattern`), `eval_real.c`, and
  `eval_string.c`. Verified: element-wise, pattern, variable-index
  read/write, scalar-property regression, and shallow copy (array-aware
  `property::copy`). Test `sv_class_prop_real_string_array`.
- **#101 investigated and closed as not-a-bug.** `C d = new src;` for a
  *static* variable is a static initializer that runs before time 0
  (IEEE 1800-2017 §6.21), so it copies `src`'s pre-write state — correct
  ordering, not a copy failure (iverilog warns about the static lifetime).
  The procedural forms (`d = new src;`, or an `automatic` variable) copy
  the post-write value correctly. The #100 test uses the statement form.

## State as of 2026-07-21c (M4B known crashes: member access, array pattern, uarray func return)

- **Member access on an element of an unpacked array of a packed struct
  (`pair_t arr[N]; arr[i].m`) — FIXED (crash, read + write).** The
  unpacked index was mistaken for a packed dimension. Read path
  `elab_expr.cc` (check_for_struct_members), write path `elab_lval.cc`
  (elaborate_lval_net_packed_member_). Commit `a3cc376`. Test
  `sv_unpacked_array_packed_struct_member`.
- **Whole-array assignment pattern into a class-property unpacked array of
  a packed type (`obj.arr = '{...}`) — FIXED (was a zero-fallback
  miscompile).** The logic-property store fed the array pattern to
  `draw_eval_vec4`, which cannot evaluate an array pattern and emitted a
  "zero fallback" (arr left 0/x). New `draw_prop_array_pattern` stores
  each element via `%store/prop/v/i`. Handles packed-struct arrays, int
  arrays, and nested (multi-dim) patterns. Commit `658dd8b`. Test
  `sv_class_prop_array_pattern`.
- **Function returning an unpacked array assigned as a whole array
  (`r = make()`) — NO LONGER CRASHES; now a graceful diagnostic.** The
  vvp calling convention has no unpacked-array return path, so codegen
  aborted (`store_vec4_to_lval` assertion). `elaborate.cc`
  (PAssign::elaborate netuarray branch) now detects a uarray-returning
  `NetEUFunc` r-value and emits a clean `sorry`. Full support (a real
  unpacked-array return path) remains open — issue #99. CE test
  `sv_uarray_func_return_fail`.
- **Filed #100:** class-property unpacked arrays of `real`/`string` store
  every element to the same slot (broken even element-wise; no indexed
  real/string property store opcode). Distinct, deeper defect; not
  touched by the array-pattern fix (which only covers logic/packed
  elements).
- Module-scope nested literal into an unpacked array of packed struct
  (`arr = '{'{..},'{..}}`) works on all probed shapes (positional, named,
  struct-of-struct, 2-D). Each increment ivtest name-diff clean (44
  expected, 0 new, 0 stale).

## State as of 2026-07-21b (P0 $unit timescale + array-of-object property crash)

- **`$unit` class timescale (P0) — FIXED.** `$time`/`$realtime` in a
  `$unit`-scope class method scaled to `$unit` (1 s) -> stored `$time` gave
  0. `vpi/sys_time.c` `sys_time_scope()` now stops the scope walk before a
  package/`$unit`. Commit `8e60735`. Test `sv_unit_class_timescale`.
- **`arr[i].prop` for a static array of class handles (#97) — FIXED
  (crash + store + read).** Was an ivl crash; the l-value elaboration
  dropped the array index + property, and the read base dropped the index
  too. Fixes in `elab_lval.cc`, `tgt-vvp/stmt_assign.c`, `elab_expr.cc`.
  Commits `e370bdf`, `40e0f26`. Test `sv_array_obj_prop_store`.
- All on PR #96; each increment ivtest name-diff clean (44 expected, 0
  new). Next manifesto item: M4B known crashes (nested packed-struct array
  literal; unpacked-array typedef return + assignment pattern).

## State as of 2026-07-21 (P0 per-instance class events + fork double-reap fix)

- **Per-instance class events (P0) — IMPLEMENTED.** Non-static class
  `event` properties are now per-instance (IEEE 1800-2017 15.5): `->obj.ev`
  triggers only that object's event, `@(obj.ev)` waits on the correct
  object. Runtime = a lazily-allocated `vvp_net_t` + `vvp_named_event_dyn`
  per (object, global slot) on `vvp_cobject`; new opcodes `%evt/obj`,
  `%evt/obj/nb`, `%wait/obj`, `%evtest/obj`. Compiler = `NetEvTrigObj` /
  `NetEvWaitObj` + IR types `IVL_ST_{TRIGGER,NB_TRIGGER,WAIT}_OBJ`;
  `elaborate_class_event_target_` (elaborate.cc) resolves the object
  handle (this-handle for bare members; prefix elaborated only after
  symbol_search confirms a real net, so hierarchical `inst.ev` refs are
  never speculatively elaborated). Handles obj.ev / a.b.ev / arr[i].ev /
  assoc `m_events[k].ev`. Commit `aa42c4d`. Test
  `ivtest/ivltests/sv_class_event_per_instance.v`.
- **Fork double-reap crash — FIXED (pre-existing, independent).**
  `vthread_reap` didn't empty its child sets, so of_DISABLE_FORK's second
  reap of an already-reaped detached child tripped `child->parent == thr`.
  Made reap idempotent (pop-erase). Commit `a3b591b`. Test
  `ivtest/ivltests/fork_disable_detached_grandchild.v` (no class events).
- **Validation:** full vendored ivtest name-diff CLEAN (44 expected
  failures, 0 new, 0 stale). UVM front-door stress passes. Both new tests
  pass.
- **REMAINING M7 blocker (layer-3, separate):** the UVM
  `phase_hopper_objection` never all-drops to the top (uvm_root) under
  concurrent objection traffic -- its integer count for uvm_root never
  returns to 0 (all_dropped is called for every component key but never
  uvm_root). This is objection COUNT propagation, independent of events;
  the shared-event cross-wake previously masked it. Blocks clean run-phase
  completion in `m7_objection_stress_test` (counters pass; end-of-sim time
  check fails -> on harness KNOWN_FAIL). **Next:** trace m_propagate /
  m_drop for a `uvm_phase`-keyed objection climbing to m_top; see
  session log 2026-07-21 for the instrumented evidence.
- **Also found (unrelated P1 crash, filed):** `arr[i].prop = expr` where
  `arr` is an unpacked array of class handles crashes ivl in
  `show_stmt_assign_sig_cobject` -> `ivl_expr_value(NULL)`. No events.
- **Known limitation:** `obj.ev.triggered` still uses the shared-event
  path (%evtest/obj opcode exists but isn't wired into expression
  elaboration yet); pre-existing, not a new regression.

## State as of 2026-07-17e (M12B-cb: assertion VPI callbacks)

- **`vpi_register_assertion_cb` now works** for
  `cbAssertionSuccess`/`cbAssertionFailure`. Each synthesized checker,
  when any assertion callback is registered (`$ivl_assert_cb_active()`),
  emits `$ivl_assert_report(idx, reason)` at every fail-dispatch site
  (via `sva_fail_action_`, all 7) and on the pass path for
  `assert`/`assume` (`pform.cc`). The systf (`vpi/sys_sva.c`) forwards to
  `vpip_assertion_report(idx, reason, scope)` which looks up the
  `__vpiAssertion` by `(scope, compile-time idx)` — so a module
  instantiated N times keeps N distinct assertion identities — and fires
  each matching registered callback with an `s_vpi_time` built from
  `schedule_simtime()` (`vvp/vpi_scope.cc`). `vpi_register_assertion_cb`
  appends to the handle's callback vector and bumps a global count backing
  `vpip_assertion_cb_active()`.
- **Windows portability**: the four new module→core calls
  (`vpip_register_assertion` [M12B], `vpip_assertion_report`,
  `vpip_assertion_cb_active`, `vpi_register_assertion_cb`) route through
  the `vpip_routines_s` table (field + `libvpi.c` forwarder +
  `vpi_priv.cc` population); `vpip_routines_version` = 3.
- **Honesty**: `s_vpi_attempt_info.detail` (failing-expr / step handles)
  is passed as a valid pointer but not populated — the interpreter
  lowering does not retain the sub-expression object model, so step-level
  introspection would be fabricated. `attemptStartTime`/callback time = the
  report time. cbAssertionStart/Step/disable reasons are header-defined but
  not yet emitted (need per-attempt lifecycle tracking; follow-up).
- Bundled VPI test `ivtest/vpi/m12bcb_assert_cb` (clocked boolean
  assertion, pattern 1 1 0 1 0 → 3 success / 2 failure, verified via
  `$check_assert_cb`). **Bundled VPI 81/81**, UVM 177/177 (zero no-check —
  report gated by `$ivl_assert_cb_active()`), negative 32/32,
  ivtest baseline-identical.

## State as of 2026-07-17d (M12B: assertion VPI object model)

- **`vpi_iterate(vpiAssertion, ...)` now works** — concurrent assertions
  have VPI identity. Because the SVA engine lowers each assertion to a
  synthesized always-block, identity is restored by **runtime
  registration**: each checker's init block calls
  `$ivl_register_assertion("name","file",line)` at time 0 (`pform.cc`);
  the systf (`vpi/sys_sva.c`) forwards to `vpip_register_assertion`
  (`vvp/vpi_scope.cc`), which builds a `__vpiAssertion` handle
  (vpiName/vpiFullName/vpiFile/vpiLineNo/vpiScope), adds it to a global
  registry, and attaches it to the scope's `intern` list. So global
  `vpi_iterate(vpiAssertion, 0)` (new case in `vpi_priv.cc`) and
  scope-scoped `vpi_iterate(vpiAssertion, scope)` (served free by the
  existing subset iterator) both enumerate every assertion.
  `vpiAssertion` = 686 (`sv_vpi_user.h`); `vpip_register_assertion`
  declared in `vpi_user.h` following the portable
  `vpip_make_systf_system_defined` cross-module pattern.
- Bundled VPI test `ivtest/vpi/m12b_assert_vpi` (three assertions,
  global + scope-scoped, attribute checks). **Bundled VPI 80/80**, UVM
  177/177 (zero no-check), negative 32/32.
- Remaining M12B: assertion **callbacks** (cbAssertionStart/Success/
  Failure) and VPI force/release on bit-selects.

## State as of 2026-07-17c (assertion control + frontier findings)

- **Assertion control** (§20.12): `$asserton`/`$assertoff`/`$assertkill`
  implemented (global scope). `vpi/sys_sva.c` holds a global enable flag
  + the `$ivl_sva_enabled()` query + the three control tasks; `pform.cc`
  `sva_gate_()` wraps every synthesized-checker fail action in
  `if ($ivl_sva_enabled())`. Flag defaults on → existing assertions
  unchanged. Test `m9e_assert_control_test`. UVM 177/177 (zero no-check),
  negative 32/32.
- **Frontier findings** (roadmap correction, see
  `session_logs/2026-07-17_frontier_assert_control_dpi_findings.md`): DPI
  **export** is architecturally blocked (no C-symbol synthesis in an
  interpreter + the disabled `IVL_SCHED_CALLF` synchronous-call
  protocol); **multi-dimensional open arrays** need non-contiguous access
  (a 2-D unpacked darray is a `vvp_darray_object`, non-contiguous); the
  remaining **M9D** features need an automaton engine. Next genuinely
  bounded items: M12B (assertion VPI identity) and pieces of M1B.

## State as of 2026-07-17b (M9C-live, M9D, M10 packed vectors)

- **M9C-live** — SVA liveness operators `nexttime`/`s_nexttime`/
  `s_eventually` (boolean operands), reusing the per-cycle + `pend`/FINAL
  machinery. `nexttime` fails at T≥1 on `!p` (a `$past(1,1)` guard skips
  the first cycle); the strong forms add an end-of-sim obligation.
  Unbounded `eventually` is now a proper LRM error. op_types 9/10/11.
  Test `m9c_live_test`; negatives `m9c_eventually_unbounded`,
  `m9c_nexttime_sequence_operand`.
- **M9D** — parameterized named properties/sequences: `sequence
  name(formals); …` / `property name(formals); …`, with the formals
  substituted (`sva_clone_subst_`) at each instantiation. Sequences
  expand in the splice pass (arity check + recursion guard, nesting
  supported); properties expand in `pform_make_assertion` with the clock
  taken from the assertion site (a clock in the body is a loud sorry).
  Signal/boolean formals only. Test `m9d_param_test` (swapped-arg
  discriminator); negatives `m9d_param_arity_mismatch`,
  `m9d_param_clocked_body`. Zero new bison conflicts. (M9D's local vars /
  `.matched` / `expect` / goto-rep remain — they need an automaton engine.)
- **M10** — DPI packed vector marshaling for wide (>64-bit) arguments:
  2-state `bit[W]` → `svBitVecVal[]` ('V'), 4-state `logic[W]` →
  `svLogicVecVal[]` ('W'), passed as a pointer, input/output/inout, any
  width, X/Z preserved for 4-state. tgt-vvp emits the letter + the usual
  `%load/vec4`/`%store/vec4`; vvp packs/unpacks the vec4 to/from a heap
  buffer and passes it via libffi like an open-array handle. Test
  `m10_dpi_wide_vector_test` (72-bit xor / copy / read-write invert).
  (M10B remaining: multidim open arrays, DPI export.)
- **Regression-clean throughout**: UVM 176/176 (zero no-check) after M10;
  ivtest baseline-identical each increment (the `pow_ca_signed` load
  flake aside); negative 32/32. Commits: `39e4af7` (M9C-live), `dedd110`
  (M9D), `5f09e4d` (M10).
- **Next**: DPI export (C-calls-SV), then multidim open arrays; M9D
  automaton features; M12B; M1B.

## State as of 2026-07-17a (M9B/M9C: intersect, until family, within)

- **Four SVA operators implemented**, replacing loud sorries. All in
  `pform.cc` (lowering) + `parse.y` (grammar); no runtime opcode change.
- **M9B `intersect`** (16.9.6): equal-length fixed operands lowered to a
  per-cycle AND unit-delay chain that the existing linear token engine
  handles. Helper `sva_expand_fixed_` turns a fixed sequence into a
  per-cycle boolean array (gap cycles = null). Unequal/variable lengths
  are loud, spec-cited sorries. **M9B COMPLETE.**
- **M9C `until` family** (16.12.10): `until`/`until_with` and strong
  `s_until`/`s_until_with`, boolean operands. Under overlapping-attempt
  semantics the aggregate collapses to a per-cycle check (`until`: fail
  on `!p&&!q`; `until_with`: fail on `!p`); strong adds an end-of-sim
  liveness obligation via a `pend` flag → FINAL `$error`. New op_types
  4–7 on `sva_property_t`, dispatched inside `pform_make_assertion` (new
  `pform_make_temporal_assertion_`) where `kind` is known. Sequence
  operands are a loud sorry.
- **M9C `within`** (16.9.6): fixed-length operands (len s1 ≤ len s2).
  Lowered to a `$past`-sampled combinational match indicator — AND of
  s2's cycles AND'd with the OR over embedding offsets of s1's cycles —
  with a `$past(1,L2)` warm-up guard. Reuses `sva_rewrite_sampled_`,
  which already expands `$past(x,k)` into history chains. op_type 8.
- **Regression-clean**: UVM **173/173** (169 baseline + 4 new SVA tests,
  zero no-check), ivtest name-diff **baseline-identical** (99 fails),
  negative **28/28** (+4 new: unequal-len/variable-len intersect,
  until-sequence-operand, within-left-longer). Tests:
  `m9b_intersect_test`, `m9c_until_test`, `m9c_until_live_test`,
  `m9c_within_test`.
- **Next** (loud, not silent): M9C-live (`nexttime`/`eventually`/
  `s_eventually`), then M10B / M12B / M1B.

## State as of 2026-07-16f (M4-av: string/real-valued assoc reads)

- **M4-av implemented** — the last *silent* miscompile from the truth
  audit is closed. A module-static (bare-signal) `string s[int]`,
  `string s[string]`, `real r[int]`, or `real r[string]` stored a value
  via `%aa/store/{str,r}/*` but read it back via a *positional*
  `%load/dar/{str,r}`, silently returning the empty string / 0.0. The
  vec4-valued int-key case was fixed in M14; the string/real value cases
  remained wrong. Class-member assoc reads (via `%prop/obj`) were always
  correct — only the bare-signal path was broken.
- **Fix** (codegen only): `tgt-vvp/eval_string.c` and
  `tgt-vvp/eval_real.c` now detect an assoc-compat bare-signal container
  (`ivl_type_queue_assoc_compat`) and emit the keyed
  `%aa/load/{str,r}/{v,str}` sequence (draw key, `%load/obj v%p_0`,
  keyed load, `%pop/obj 1`) instead of the positional load — string-key
  and vec4(int)-key branches added after the existing obj-key branch.
  Opcodes already existed (used by the `%prop/obj` class-member path);
  no runtime change.
- **Regression-clean**: UVM **169/169** (168 baseline + new m4av test),
  **zero no-check**, zero fail; ivtest name-diff **baseline-identical**
  (99 real fails; `pow_ca_signed` is the documented concurrent-load
  flake — passes standalone); negative **24/24**. Test:
  `tests/m4av_assoc_value_types_test.sv` (int/string keys, updates,
  `foreach`, `exists`/`delete`, missing-key defaults, positional queues
  kept on `%load/dar`).
- **Both silent miscompiles from the truth audit (M3-rm, M4-av) are now
  closed.** Next priority (loud, not silent): M9C/M9B temporal/sequence
  operators `within` / `until` / `until_with` / `intersect`.

## State as of 2026-07-16e (M6B: program-completion ends simulation)

- **Program-completion-ends-simulation implemented** (IEEE 1800-2017
  24.7/3.9): a program that completes naturally now ends the simulation
  (was: ran to the testbench watchdog). Program `initial` procedures are
  marked `.thread $prog` (tgt-vvp, `ivl_scope_program`); the runtime
  counts them and calls `schedule_finish(0)` when the last completes
  (vvp/vthread.cc). Only run-once initials are counted, so program
  assertions/clocking (always-type) never keep the sim alive.
- Verified: single program ends at completion; two programs end only
  after the LAST; fork..join completes after join; no-program designs
  unaffected. **Regression-clean**: UVM 168/168 (zero no-check), ivtest
  name-diff baseline-identical (57 program-block cases unaffected),
  negative 24/24. Test: `tests/m6b_program_finish_test.sv`.
- With `$exit`, both program-control gaps of clause 24.7 are now closed.
  Remaining M6B ledger: cbNBASynch/post-NBA VPI regions, DPI
  time-consuming tasks, callf scheduled-call protocol.
- **Next**: M4-av (string/real-valued int-keyed assoc reads — remaining
  silent miscompile), then M9B/M9C (`within`/`until`/`intersect`).

## State as of 2026-07-16d (M6B scheduler conformance + $exit)

- **M6B delivered**: construct-level scheduler conformance inventory
  (`docs/conformance/scheduler_conformance_inventory.md`) — 20 scheduling
  constructs mapped to runtime path + IEEE 1800-2017 clause-4 region +
  observed behaviour + permanent test, backed by 18 event-region litmus
  probes (all green: NBA swap, blocking/#0 pre-NBA reads, `->>`,
  `e.triggered`, continuous-assign-after-NBA, inertial cancel, `$strobe`
  post-NBA, `wait fork`, `disable fork`, program/reactive ordering).
- **`$exit` implemented** (IEEE 1800-2017 24.7): was an undefined-systask
  load error; now ends the calling program (quiet finish). `vpi/sys_finish.c`.
  Multi-program early-exit and program-completion-ends-sim are recorded
  M6B follow-up gaps (the latter deliberately not implemented — would
  risk the 57 ivtest + 3 harness program-block tests).
- **Tests**: m6b_scheduler_litmus_test.sv, m6b_exit_test.sv. Evidence:
  negative 24/24; existing m6_sched/reactive/program tests pass; UVM +
  ivtest sweeps (pending final confirm).
- **Next**: M4-av (string/real-valued int-keyed assoc reads — remaining
  silent miscompile), then M9B/M9C (`within`/`until`/`intersect`).

## State as of 2026-07-16c (MILESTONE TRUTH AUDIT + 2 reopened fixes)

**Milestone status corrected** — see
`docs/conformance/milestone_truth_audit_2026-07-16.md`. Prior "CLOSED"
labels overstated reality: in-scope functionality was sitting in
recorded-corners ledgers. Honest labels now:
- M1 → **SUBSET COMPLETE (M1A)**; M3 → **PARTIAL** (rand_mode gap now
  fixed); M4 → **SUBSET COMPLETE** (M4-av assoc-value corner);
  M6 → **PARTIAL (M6B reopened)**; M9 → **SUBSET COMPLETE**
  (M9A done / M9B-D open); M10 → **SUBSET COMPLETE (M10B)**;
  M12 → **SUBSET COMPLETE (M12B)**; M13 → **SUBSET COMPLETE (M13B)**.
  M0/M2/M8/M11/M14 stand as COMPLETE within their scope.

**Two real technical fixes this session** (implementation, not just
relabeling):
1. **M9C SVA `throughout`** (16.9.9) — was a loud sorry, now implemented
   by lowering to a unit-delay sequence with the guard AND-ed into every
   cycle (incl. intermediate ##N wait cycles); loud sorry only for
   variable-window shapes. `pform_sva_throughout` in pform.cc.
   Adversarial + negative tests.
2. **M3-rm per-field `rand_mode(0)`** (18.8) — was a SILENT no-op
   (frozen field still randomized). Fixed generally: intercept
   `obj.field.rand_mode()` in elaborate_usr, resolve the property index,
   emit the new `%rand_mode/p` opcode. Adversarial test.

**Evidence**: UVM **165/165** (zero no-check; 163 + 2 new tests);
negative **24/24**; SVA + randomization suites pass; ivtest name-diff
(pending final confirm). Session log:
`session_logs/2026-07-16_truth_audit_throughout_randmode.md`.

**Next engineering action**: M4-av (string/real-valued integer-keyed
assoc reads — remaining silent miscompile), then M9B/M9C (`within`/
`until`/`intersect`), M6B scheduler inventory.

## State as of 2026-07-16b (M14 CLOSED)

- **M14 (IEEE 1800-2017 clause matrix with complete disposition) is
  CLOSED.** Deliverable:
  docs/conformance/matrices/ieee1800_2017_clause_matrix.md — an
  empirical, clause-by-clause disposition of every 1800-2017 clause
  (FULL / PARTIAL / DIAGNOSED / N/A) with evidence, produced by a
  five-way parallel audit whose every silent-gap candidate was hand
  re-verified (audit agents are pointers, not truth).
- **Six SILENT gaps found and closed** (principle 4):
  1. `case (x) inside` range matching (12.5.4) — was low-endpoint-only;
     now lowered to the `inside` operator (pform_make_case_inside).
  2. module-static integer-keyed assoc value read (7.8) — stored via
     %aa/store, read via positional darray load → default; fixed in
     tgt-vvp/eval_vec4.c (class-member assoc was already fine).
  3. width-1 class-property $display (8) — 1-bit bit/logic printed the
     object handle (garbage); fixed in tgt-vvp/draw_vpi.c (properties
     always evaluate to a temp). Also fixed interface-member $display (25).
  4. checker/endchecker (17) — bare syntax-error abort → explicit sorry.
  5. randcase (18.16) — silent empty block → loud sorry.
  6. std::randomize(var) scope form — success-but-no-op → loud warning.
- **Promotion evidence**: UVM **163/163** (zero no-check; 160 + 3 M14
  tests); negative **23/23**; ivtest name-diff baseline-identical
  (pending final confirm); bundled VPI 79/79 (unaffected). Session log:
  session_logs/2026-07-16_m14_clause_matrix.md. Recorded-corners ledger
  in the matrix (string-valued int-keyed assoc, 2 ICEs to harden,
  interface/nested/extern-method class corners, virtual-iface at module
  scope, $typename/%p, rand_mode(0), shallow-copy inline static init,
  etc. — all loud, none silent).
- **NEXT FRONTIER: M15 (IEEE 1800-2023 delta)** — the final milestone.

## State as of 2026-07-16 (M13 CLOSED)

- **M13 (bind, let, configs, specify, timing, rare constructs) is
  CLOSED** on PR #76, four increments in four commits:
  1. **bind** (23.11) — was silent-drop (module-item) / syntax error
     (description-level); now real semantics. Directives collected
     during parse, applied by `pform_apply_binds()` from
     `pform_finish()` after all files parsed: the bound PGModule is
     appended to the TARGET module's gates so every instance
     elaborates it in target scope. New PExpr virtual
     `reloc_lexical_pos_bind()` relocates identifier lexical positions
     to end-of-scope so bind-before-target / cross-file binds resolve
     target internals. `pform_finish()` now returns its error count to
     main. Loud errors: unknown target, self-bind, program-block
     target; loud sorries: bind-to-instance-path, target-instance-list.
  2. **let** (11.13) — was sorry; now real expression-macro
     substitution. Lets stored on the pform Module, copied to a
     NetScope table (`find_let` stops at the module boundary); a use
     clones the body with formals→actual-clones and elaborates in the
     use scope (cached per node, depth-guarded for recursion). Hooks in
     PECallFunction/PEIdent test_width+elaborate_expr. Supports
     default/named args, lets-calling-lets, selects on formals.
  3. **timing checks** (clause 31) — were warn-and-drop (violations
     never reported); now synthesized checker processes (parse-time,
     like M8/M9). $setup/$hold/$recovery/$removal/$skew/$period/$width
     and $setuphold/$recrem (paired, cloned limits) report violations
     via $display + notifier toggle, ACTIVE with -gspecify (silent
     without, matching path-delay opt-in). Loud sorries: $nochange,
     $timeskew, $fullskew, edge-descriptor lists, timestamp/timecheck
     conds.
  4. **rare constructs pinned** — strengths/rare-nets, preprocessor
     stringize/paste/nesting, const user functions, specify paths all
     locked with permanent tests; trireg stays a loud sorry; config a
     loud skip. Negative runner now accepts `sorry:` as a loud
     rejection.
- **Promotion evidence**: UVM **160/160** (zero no-check; 155 + 5 M13
  tests); ivtest failure names byte-identical to baseline (the two
  pow_ca_* under concurrent-sweep load are the documented ~24s load
  flakes, PASS standalone); negative **21/21**; bundled VPI **79/79**
  (unaffected). Session log:
  session_logs/2026-07-16_m13_bind_let_specify_timing.md (ledger:
  bind-to-instance/list, typed let ports + non-module-scope lets,
  $nochange/$timeskew/$fullskew + edge-descriptors + tstamp conds,
  config skip, trireg).
- **NEXT FRONTIER: M14 (clause conformance matrix)**; then M15
  (1800-2023 delta).

## State as of 2026-07-15h (M12 CLOSED)

- **M12 (VPI SystemVerilog object model) is CLOSED** on PR #76, four
  increments in three commits:
  1. **SV variables/containers/class members** — FIXED the
     vpi_put_value crash on darray elements (unsized vector into
     setarray); queues got full element access (__vpiQueueVar :
     __vpiDarrayVar; vpiArrayType detected from the live object);
     assoc arrays got vpiSize/vpiArrayType/key-ordered positional
     iteration (vvp_assoc_base::peek_entry; element writes = loud
     sorry); class variables got vpiMember iteration with stable
     typed member handles (read AND write via the live object) and
     dotted-path by-name descent (one level); vpiVariables includes
     SV var types; value-change callbacks on string (every change)
     and class/container vars (handle assignment) via a functor-
     carried callback list; assert-happy defaults de-crashed.
  2. **Scopes** — interface instances report vpiInterface (NetScope
     is_interface → ivl_scope_is_interface → '.scope interface' →
     vpiScopeInterface; vpip_module treats interface/program as
     module-like); modports are vpiModport (603) objects iterable
     from the interface scope; package-qualified
     vpi_handle_by_name("pkg::item"); new ivl_target APIs in ivl.def.
  3/4. **Covergroups** — vpi_iterate(vpiCovergroup(605), NULL) yields
     per-type handles with live type-coverage reads (M11 registry).
     Assertion VPI = recorded corner (no runtime assertion
     identities in the synthesized-checker design).
- **Promotion evidence**: bundled VPI suite **79/79** (3 new
  gold-file regressions m12_sv_{objects,scopes,coverage} — CI runs
  these via .github/test.sh); external ivtest VPI baseline-identical
  (11 legacy PLI/TF fails unchanged); UVM **155/155** (zero
  no-check); ivtest byte-identical (empty diff); negative 14/14.
  Session log: session_logs/2026-07-15_m12_vpi_sv_object_model.md
  (ledger: nested member descent, in-place mutation callbacks,
  assoc element writes, modport directions, bit-select force,
  cbForce/cbRelease, assertion VPI, covergroup drill-down,
  free_object no-op).
- **NEXT FRONTIER: M13 (bind, let, configs, specify, timing, rare
  constructs)**; then M14 clause matrix, M15 1800-2023 delta.

## State as of 2026-07-15g (M11 CLOSED)

- **M11 (functional coverage) is CLOSED** on PR #76, four increments
  in three commits:
  1/2. **Bin semantics core + transitions** — metadata records became
     (cp, prop, lo, hi, kind, tuple, item): same-(prop,tuple) records
     AND (cross tuples), tuples OR (fixing the live silent miscompile
     where multi-range bins {1,5} could NEVER hit). Arrayed bins
     ([]/[N]), with-filters (item-substitution constant evaluator),
     wildcard bins (x/z/? masks), default bins (counted, excluded
     from %), ignore CARVE-OUT (values suppress the whole coverpoint
     incl. crosses), illegal precedence + runtime error, iff guards
     (%covgrp/sample gained has_guards), automatic bins
     (auto_bin_max), transition bins (multi-step/multi-seq/range
     steps, per-instance NFA masks on vvp_cobject), options captured
     and applied (at_least/auto_bin_max/weight), get_inst_coverage =
     weighted per-ITEM model (19.11; coverage_cross_test expectation
     updated 75%→83.3% with pinned reasoning), ALL silent grammar
     drops now loud sorries. +7 r/r conflicts in pre-existing benign
     families (sweep-validated).
  3/4. **binsof crosses + queries + report** — named cross bins with
     binsof(cp[.bin])/intersect/&&/||/! evaluated per product tuple
     (normal collect, ignore carve out, illegal error+precedence,
     rest auto); type coverage (per-class merged counters,
     get_coverage()), $get_coverage (registry mean; registered
     real-returning sysfunc), start()/stop(), durable text report
     via IVL_COVERAGE_REPORT=<file|->.
  Fixed en route: LATENT pform teardown double-free (comma property
  lists / typedef aliases share one data_type_t under owning
  unique_ptrs; module-scope classes w/ covergroups crashed AFTER
  writing output — verified pre-existing on the M10 compiler; fix:
  release-not-delete at exit). Windows CI: new ivl_type_covgrp_*
  APIs added to ivl.def (all three MSYS2 jobs failed the tgt-vvp
  link — caught from PR webhook, fix pushed).
- **Promotion evidence**: UVM **155/155** (zero no-check), ivtest
  2559/2456/100 identical to baseline modulo the documented
  pow_ca_signed flake (verified standalone PASS 24.1s), negative
  14/14, battery 16/16. Session log:
  session_logs/2026-07-15_m11_functional_coverage.md (ledger:
  package/module-scope cg stubs loud, sampling events, with-function-
  sample formals, non-property coverpoint exprs, guard forms, 2-state
  sampling, UCDB, caps).
- **NEXT FRONTIER: M12 (VPI SystemVerilog object model)** per the
  milestone sequence; then M13 (bind/let/configs/specify), M14
  clause matrix.

## State as of 2026-07-15f (M10 CLOSED)

- **M10 (DPI and open arrays) is CLOSED** on PR #76, four increments:
  1. **libffi marshaling core** — exact per-argument ABI from a
     compiler-emitted signature string (`[+][u]<letter>` tokens:
     b/h/i/l ints by width, g svLogic scalar, r real, s string,
     o open array); fixed the mixed int/real/string ABI break, the
     8-arg cap, silent >32-bit truncation, AND a silent elision of
     void DPI call statements (empty-pform-body optimization —
     elaborate.cc now exempts DPI imports). Legacy non-libffi
     fallback kept (uniform signatures, loud otherwise). `-lffi` +
     `-DUSE_LIBFFI` wired like z3; libffi added to apt/brew/MSYS2 CI.
  2. **Grammar** — import "DPI-C" task (pure task = hard error,
     35.4), `c_name = function/task` alias binding, all export forms
     loud sorries. Zero new bison conflicts (458/1103). DPI flag
     moved PFunction→PTaskFunc; TASK scope plumbing in t-dll;
     draw_task_definition synthesizes DPI task bodies.
  3. **Output/inout args** — pointer marshaling with copy-back via
     port-var stores + the standard call machinery; output ints
     restricted to atom widths (8/16/32/64) or 1-bit; string outputs
     const char**; svBit/svLogic 1-bit both directions w/ 4-state
     encoding (sv_z=2, sv_x=3).
  4. **Open arrays** — 1-D dynamic arrays of atoms/real as
     svOpenArrayHandle sharing simulation storage (writes visible,
     no copy-back); svdpi accessor subset exported from vvp
     (rdynamic + vvp.def); new installed svdpi.h.
- **Promotion evidence**: UVM **152/152** (zero no-check), ivtest
  BYTE-IDENTICAL to baseline (2559/2457/99, empty name-diff),
  negative 14/14, battery 10/10. Real-UVM check: uvm_pkg.sv compiles
  rc=0 WITHOUT UVM_NO_DPI — regex/cmdline/polling imports genuinely
  marshaled; only recorded sorries remain (4× uvm_hdl 1024-bit
  svLogicVecVal, 2× export). Session log:
  session_logs/2026-07-15_m10_dpi_open_arrays.md (recorded-corners
  ledger: svLogicVecVal/svBitVecVal vectors, exports, non-atom open
  arrays, chandle-as-longint, context no-op, fallback limits).
- **NEXT FRONTIER: M11 (functional coverage)** per the milestone
  sequence (M12 VPI object model after; M14 clause matrix becomes
  tractable once those land).

## State as of 2026-07-15e (M9 CLOSED)

- **M9 (core SVA engine) is CLOSED** on PR #76. On top of increment 1
  (token-pipeline checkers, sampled |->/real |=>, ##N chains,
  trailing ##[m:n] windows, sampled-value functions, named no-arg
  declarations, defaults, cover), M9-2 added: consecutive repetition
  e[*N] / final e[*m:n] (new K_LBSTAR lexer token — '[*' vs
  bit-selects needs lexing, both pinned); FIXED-delay sequence
  antecedents via history-AND match detection (overlap-correct, to
  128 cycles); not(seq); first_match transparency + parenthesized
  sub-sequence atoms; unbounded ##[m:$] weak-eventually windows with
  end-of-simulation pending reports (synthesized final process);
  pass actions at all match sites; loud compile-progress sorries for
  until/nexttime/eventually/intersect/within/throughout.
- **Promotion evidence**: UVM **148/148** (zero no-check), ivtest
  identical to baseline modulo the documented pow_ca_signed flake
  (verified standalone PASS), negative 13/13, battery 16/16.
  Tests: m9_sva_engine_test.sv, m9_sva_algebra_test.sv,
  m9_sva_unbounded_test.sv. Session log:
  session_logs/2026-07-15_m9_core_sva.md (includes the
  recorded-corners ledger: parameterized declarations, sequence
  and/or, goto/nonconsecutive repetition, local sequence variables,
  .triggered/.matched, expect, checkers 17.x, exact-Preponed
  blocking-race sampling).
- **NEXT FRONTIER: M10 (DPI and open arrays) or M11 (functional
  coverage)** per the milestone sequence; M14's clause matrix
  becomes tractable once those land.

## State as of 2026-07-15d (M9 increment 1 LANDED AND PROMOTED)

- **PR #76** now carries the full M8 tail (promoted, M8 CLOSED) AND
  M9 increment 1: the core SVA engine (G05/G06). Concurrent
  assertions lower to synthesized token-pipeline checkers
  (pform_make_assertion, pform.cc): sampled |->, REAL |=> (was
  approximated as |->), ##N chains, trailing ##[m:n] windows,
  overlap-correct attempts, disable iff + `default disable iff`
  (now applied), default-clocking assertions, sampled-value
  functions ($rose/$fell/$stable/$changed/$past[,N]) with true
  clocked histories, named no-arg property/sequence declarations,
  assume==assert, cover counting, restrict ignored per 16.8.
  Honest sorries for the unsupported algebra.
- **Promotion evidence**: UVM **146/146** (zero no-check), ivtest
  BYTE-IDENTICAL to baseline (empty diff), negative 13/13.
  Test: tests/m9_sva_engine_test.sv (24 checks, pass+fail
  directions). Session log:
  session_logs/2026-07-15_m9_core_sva.md.
- **M9-2 frontier (next)**: repetition operators ([*N]/[->]/[=]),
  sequence antecedents, non-final ranges, unbounded ##[m:$],
  property operators (not/until/nexttime), throughout/intersect/
  first_match, parameterized declarations, pass actions, exact
  Preponed sampling for blocking-race corners.

## State as of 2026-07-15c (M8 CLOSED; M9 is next)

- **PR #75 MERGED** (M4 close-out + M8 increment 2 core). **PR #76**
  (draft, branch restarted from merged main) carries the M8 tail:
  T1 vif.cb.out buffered drives (%vif/tickchg, obuf/opend as
  interface properties); T2 global clocking + $global_clock
  (14.14, G59 FIXED); T3 clocking_decl_assign (signal-path form);
  T4 scalar `x <= ##N v` via the $ivl_default_clock marker;
  T5 diagnosed edge-qualified skews.
- **Promotion evidence**: UVM **145/145** (zero no-check), ivtest
  failure names identical to baseline modulo the documented
  pow_ca_signed flake (verified standalone PASS), negative 13/13.
  **M8 is CLOSED** — remaining corners all explicitly diagnosed,
  never silent (edge-qualified skew application, real/string/array
  clockvars, output decl_assign, vif output skew values,
  force-vs-history).
- **NEXT: M9 core SVA engine (G05/G06).** Recon done (see
  session_logs/2026-07-15_m8_tail_closeout.md): current assert
  property is a parse-time always-block lowering with LIVE
  (unsampled) evaluation, |=> approximated as |->, no sequences,
  $past stubbed. Increment-1 plan: (1) sampled evaluation via
  %hist/on+%load/preponed with checking at %wait/observed; (2) real
  |=> (1-cycle sampled antecedent pipeline); (3) ##N/##[m:n]
  consequent delays; (4) $rose/$fell/$stable/$past on sampled
  history; (5) named property/sequence declarations; (6) honest
  sorries for the remaining sequence algebra.


## State as of 2026-07-15b (M4 FULLY CLOSED; starting M8 increment 2)

- **M4 close-out commit 928440d** fixed all five recorded residuals in
  one increment: G70 (class-method calls on plain-darray elements —
  element-select routing extended from queue-only to darrays), the
  $size family on dynamic-container property receivers
  ($size/$high/$low/$left/$right/$increment/$unpacked_dimensions now
  rewrite to the queue-size sfunc per 20.7, darrays 0-based),
  display-context chained property reads (vpi arg classifier no longer
  falls back to the class-typed root signal for BOOL/LOGIC/REAL/STRING
  value types), G40 unique/unique_index on fixed-size unpacked arrays
  (new `%uarr/unique` opcode, 7.12.1), and G73 empty-queue literal
  `{}` producing a real empty queue instead of a nil handle
  (`$ivl_queue$new_empty` sfunc → `%new/queue`/`%new/darray`, 7.10.4).
- **Promotion evidence (this entry)**: UVM sweep 137/137 PASS
  (includes new tests/m4_closeout_test.sv; zero FAIL, zero
  "(no-check)" audit entries); ivtest sweep
  Total=2559 Passed=2457 Failed=99 — failure NAMES byte-identical to
  the pristine-baseline fails_baseline.txt (empty diff); negative
  suite 10/10. **M4 is CLOSED with no recorded residuals.**
- **M8 increment 2a LANDED (WIP commit, sweeps pending)**: sampled
  clocking-block inputs (IEEE 1800-2017 14.13) replacing the alias
  model for module, program, and interface-INSTANCE-path clocking
  blocks:
  - 2a-1 direction plumbing: parse.y records input/output/inout per
    clocking signal into Module::PClocking (directions map +
    signal_direction; unknown → PINOUT) and
    netclass_t::clocking_block_t (as int).
  - 2a-2 vvp machinery: vvp_wire_vec4 opt-in 1-deep driven-value
    history (hist_snapshot_ on first change per time step);
    `%hist/on` enables it; `%load/preponed` returns the value at the
    START of the current step (= Preponed value = default #1step
    sample), degrading to the current value on non-vec4 filters.
    Known limitation: history tracks the DRIVEN value (force corner).
  - 2a-3 synthesis + routing: elab_sig creates `_ivl_smp$<cb>$<sig>`
    sample vars + `_ivl_smptrig$<cb>` trigger event per instance;
    elaborate synthesizes `initial { $ivl_clocking_hist_on(raw)...;
    forever @(ev) { smp <= $ivl_clocking_sample(raw)...; ->> trig } }`.
    NBA stores + NB trigger give deterministic visibility: raw-edge
    Active readers see the PREVIOUS sample; @(cb) waiters (redirected
    to the trig event in PEventStatement elaboration, same for ##N
    default-clocking waits) see THIS edge's samples. Reads of input
    clockvars rewrite to smp vars in the shared netmisc helpers
    (same-scope + inst.cb.sig paths, read/write mode parameter);
    writes to inputs are errors (14.3, negative test); outputs keep
    the alias model until 2b. Pre-first-edge clockvar reads are X.
  - **General `->>` fix (15.5.1)**: vvp of_EVENT_NB delivered the
    trigger to the event functor's FANOUT (schedule_propagate_event)
    instead of its port 0, so ->> never woke waiters and tgt-vvp
    carried a stale sorry. Now schedules a port-0 delivery in the
    NBA region (Re-NBA from reactive/program threads to order after
    the same thread's NBA stores). The sorry is removed — ivtest may
    show newly-passing ->> tests (diff-only-removals = improvement).
  - Tests: tests/m8_clocking_sample_test.sv (13 checks: between-edge
    hold, same-step-blocking-write race closed, deterministic @(cb)
    freshness, inout sampling, pre-edge X);
    tests/negative/m8_clocking_input_write.sv (negative now 11);
    clocking_test.sv updated to strict 14.13 (@(cb) to observe the
    new sample; raw-edge readers see the previous one); g01 header
    updated.
- **M8-2a-4 LANDED (WIP, sweeps pending)**: vif.cb.sig sampled
  through class handles — sample vars + tick bit registered as
  interface-class PROPERTIES (runtime resolves by name in the bound
  scope); @(vif.cb) → anyedge wait on the tick property (%wait/vif
  machinery); writes to inputs via vif are 14.3 errors. SECOND
  general ->> fix: NetEvent::nnb_trig() added to nodangle's event
  liveness test — events referenced only by ->> were deleted and
  codegen segfaulted on the dangling pointer. Tests:
  m8_vif_clocking_sample_test.sv, negative
  m8_vif_clocking_input_write.sv (suite 12/12).
- **M8-2b LANDED AND PROMOTED** (UVM 140/140 zero no-check, ivtest
  empty diff): buffered output clockvar drives per 14.16 —
  `_ivl_obuf$`/`_ivl_opend$` vars per output, PAssignNB transform
  with the tick-history "did the event occur this step" test (drive
  now after @(cb), buffer between events), synthesized apply process
  at the trigger (Re-NBA-like timing), last-drive-wins. Fall-throughs
  to alias (recorded): vif.cb.out drives, part-select drives,
  unsampleable signals.
- **M8-2c LANDED (sweeps running)**: `cb.out <= ##N v` parses and
  lowers at parse time (pform_make_clocking_drive) to
  `lval <= repeat(N) @(cb-prefix) v` — value captured at issue,
  landing at the Nth clocking event via the trigger redirect,
  independent overlapping drives. Sorry (recorded): scalar
  default-clocking form `x <= ##N v`.
- **M8-2c LANDED AND PROMOTED** (UVM 141/141, ivtest empty diff):
  `cb.out <= ##N v` lowers at parse to `<= repeat(N) @(cb) v` —
  value captured at issue, independent overlapping drives.
- **M8-2d (skew application) LANDED AND PROMOTED** (UVM 142/142,
  ivtest empty diff): numeric input skews sample transport shadows
  read at the OBSERVED region (new `%wait/observed` opcode — first
  real consumer of the M6 region foundation; #0 = settled post-NBA
  value, #d = value d before the edge); output skews delay the drive
  landing (both apply-process and direct paths); block default skews
  apply. Tests: m8_clocking_cycle_drive_test.sv,
  m8_clocking_skew_test.sv.
- **M8 INCREMENT 2 CORE COMPLETE.** Remaining tail (recorded in the
  session log, priority order): clocking_decl_assign; global
  clocking + $global_clock (14.14/G59); vif.cb.out buffered drives
  (preponed-through-property); scalar default-clocking `x <= ##N v`
  (diagnosed sorry); edge-qualified skew application; real/string/
  array clocking signals (alias + sorry). Other recorded 2a
  limitations: force tracks driven value; @(cb) from a scope
  elaborated BEFORE the defining instance falls back to the raw
  event.
  Sweep procedure reminder: UVM harness and ivtest MUST run with
  PATH=/home/user/iverilog-install/bin (or ivtest shim) prefixed;
  `which iverilog` otherwise finds nothing and everything
  COMPILE_FAILs.

## State as of 2026-07-15 (session: M3/M4/M5 close-out)

- **Branch**: `claude/ieee1800-uvm-implementation-qm5wad` (PR #75,
  draft). Six checkpoints stacked on the G71/M3-ranges work:
  M3A dynforeach (a48718a), M3B solve...before (5654a78),
  M4a uarray ordering + G72 signed sort (254d1db),
  M4b darray/property store2 outers (aeee8f9),
  M5 interface ports/modports G26-G29 (c399625), plus the promotion
  commit with the group regression evidence.
- **Milestone status after this session**:
  - **M3 CLOSED** (dynamic foreach, non-0-based ranges,
    solve...before all implemented).
  - **M4 main tail CLOSED** (G35/G36 ordering methods on unpacked
    arrays; G72 signed container sort; chained element stores through
    darray/property outers). Remaining recorded: G40
    unique-on-unpacked (expression form, rare); display-context
    chained reads; $size family on property receivers; G70
    indexed-element methods; G73 (NEW) `q.push_back({})` pushes nil.
  - **M5 CLOSED** (620c3a8/0eef20a on top of c399625): interface
    ports end to end; modport tf ports; b.mst binds; instance + vif
    arrays; DYNAMIC per-handle task dispatch (25.10, %jmp/vif);
    modport input-write enforcement (25.5); parameterized-interface
    port width tolerance. Recorded follow-ups: dynamic-dispatch
    copy-back for output/inout task ports (static fallback + warning
    today); full modport access restriction (unlisted members stay
    accessible); per-specialization interface class types (boundary
    resize is the interim); VIF_DISPATCH_MAX=64 instances per
    interface type.
- **M1→M8 audit (post-M5)**: recorded in the session log. M2's last
  unverified residual (dynamic uvm_field_array_int clone) PASSES.
  M4 follow-up priority: G70 indexed-element method calls (two
  visible errors in every UVM compile), then $size-family on
  property receivers (silent 'x'), display-context chained reads,
  G40, G73. M8 increment 2 itemized: #1step/#0 input sampling,
  Re-NBA synchronous drives, `cb.sig <= ##N v`, skew application,
  clocking_decl_assign, global clocking (14.14/G59).
- **Details**: `session_logs/2026-07-15_m3_m4_m5_closeout.md`.
- **Next milestone work**: M8 increment 2 (real clocking semantics,
  alias model confirmed by probe), then M9 entry (G05/G06 core SVA).

## State as of 2026-07-14k (session: milestone close-out audit + G71 foreach/property-darray family)

- **Branch**: `claude/ieee1800-uvm-implementation-qm5wad` (restarted
  from merged main at 6d9bc72 per protocol; PR #74 merged the previous
  M8-entry work — do not reopen).
- **Plan directive**: close out earlier milestones (M1-M7 tails)
  before finishing M8 increment 2 / opening M9. Re-probe audit results
  and the per-milestone snapshot are in
  `session_logs/2026-07-14_g71_foreach_prop_darray.md`. Highlights:
  G38/G39 verified already fixed (audit stale); G35/G36/G40 (M4) and
  G26-G29 (M5) re-confirmed open; M3 dynamic foreach constraints +
  non-0-based ranges re-confirmed open (warned-and-ignored);
  solve...before distribution OK for the common implication shape.
- **This checkpoint — G71 FIXED** (new gap, found by the audit):
  foreach over class-property PLAIN dynamic arrays silently iterated
  zero times (queue/assoc properties were fine). Fixed the whole
  read-side family: darray foreach now uses the 0<=i<size loop
  (elaborate.cc); indexed darray properties are element-indexed in
  object/vec4/string/real codegen (tgt-vvp; was arrayed-property
  mis-indexing → crash on nested descent); `%load/qo/*` accepts any
  vvp_darray receiver (vvp). Chained reads `c.dd[i][j]` in
  assignment/operand context now work (was ivl assertion abort).
  Test: `tests/g71_foreach_prop_darray_test.sv`.
- **Known in-family tails deferred** (see session log): chained
  element STORES through darray outers (`c.dd[i][j]=v` silent no-op —
  extend the G09 `$ivl_assoc$store2` rewrite+lowering to darray and
  property outers = next natural increment); display-context chained
  reads; `$size/$high/$low` on property receivers fold to 'x';
  indexed-element method calls (G70).
- **Checkpoint 2 (same session) — M3 non-0-based foreach constraint
  ranges FIXED** (18.5.8.1): the unroller now binds the loop variable
  to DECLARED index values and maps element solver slots
  declared->canonical; `[3:1]`/`[5:2]`-style rand arrays are now
  constrained instead of warned-and-ignored. Test:
  `tests/m3_constraint_nonzero_range_test.sv`; m3 focused suites PASS.
- **Next engineering options** (milestone order for the close-out
  plan): (a) M3 tail — dynamic-array foreach constraints (needs
  runtime foreach expansion + staged size-then-elements solve, which
  solve...before staging can share); (b) M4 tail — G35/G36/G40
  ordering/manipulation methods on unpacked fixed-size arrays (queue
  machinery exists; extend receivers), plus the store2
  darray/property-outer extension (chained element stores
  `c.dd[i][j]=v` still silently no-op); (c) M5 entry — G26 modport
  import ports (parser) then G27/G29 (elab port binding).

## State as of 2026-07-14j — PR #73 MERGED (5c05f93); branch restarted

- **PR #73 is MERGED and FINAL** (merge commit 5c05f93 on main): the
  entire M8-entry checkpoint below (G01/G02 clocking blocks in
  module/program scope, default-clocking registration, 14.4 skew
  syntax, procedural ##N cycle delays, netmisc.cc helper unification).
  Do not reopen; follow-up work gets a NEW draft PR.
- **Branch**: `claude/ieee1800-uvm-implementation-tt3pll` restarted
  from origin/main at 5c05f93 (force-with-lease over the
  already-merged history per protocol; this docs note rides on it).
- **Next engineering target (M8 increment 2)**: real clocking
  semantics — input sampling (#1step via 1-deep value/timestamp
  history = Preponed value; #0 via schedule_at_observed) and
  synchronous output drives (Re-NBA), replacing the alias rewrites in
  netmisc.cc for all scopes at once; then `cb.sig <= ##N v` drives.
  Characterization anchor: tests/g01_module_clocking_test.sv pins the
  alias behavior. Alternatives: G05/G06 (SVA, M9 entry);
  clocking_decl_assign; global clocking (14.14).

## State as of 2026-07-14i (session: M8 entry — G01/G02 clocking blocks + ##N)

- **Branch**: `claude/ieee1800-uvm-implementation-tt3pll` (fresh from
  merged main at fb79080 after PR #72; new draft PR for this work —
  became PR #73, MERGED, see 2026-07-14j above).
- **This checkpoint** opens M8 at the gap-audit entry point:
  - **G01 FIXED**: `clocking ... endclocking` in a module no longer
    crashes (was: error + pform.cc is_interface assertion + core dump);
    it is registered and functional (14.3). **G02 FIXED**: same for
    program blocks. Same-scope `@(cb)` and `cb.sig` (read + drive) now
    resolve in modules/programs — new shared
    `rewrite_enclosing_scope_clocking_member_path` in netmisc.cc; the
    two previously-duplicated interface rewrite helpers were unified
    into netmisc.cc and generalized past `is_interface` (debt
    reduction; elab_expr.cc/elab_lval.cc statics deleted).
  - **default clocking registered** (14.12): named + anonymous
    declaration forms REGISTER the block (parse-and-drop fallback
    removed); new `default clocking id;` reference form; at most one
    default per scope enforced; existence validated at endmodule.
    `Module::default_clocking` records it.
  - **Clause 14.4 skew syntax complete**: `#1step` lexes (new K_1step),
    edge skews and `default input/output skew` items parse per A.6.11;
    `ref` no longer wrongly accepted as a clocking direction. Skews are
    accepted and DISCARDED — the clocking model is still the alias
    model (cb.sig = underlying signal, no sampling/drive scheduling).
  - **Procedural ##N cycle delay (14.11)**: `##` lexes (K_CYCLE_DELAY),
    new PCycleDelay statement lowers at elaboration to
    `repeat (N) @(<default clocking>)` via the existing Phase 55 @(cb)
    resolver; clause-referenced error when no default clocking is in
    scope. Number/identifier/(expr) count forms.
  - Latent crash fixed: duplicate clocking-block name + items no longer
    dies on the pform_add_clocking_signal assertion.
- **Regressions**: UVM 129/129 (+2 new tests); ivtest vvp_reg.pl
  2961/3101 failure-name-identical to a fresh same-machine pristine
  baseline (worktree at fb79080); vvp_reg.py 284/12 and vpi_reg.pl
  76/76 baseline-identical; negative suite 9/9 (+3 new); region trace
  PASS; bison conflicts DOWN 459→458 s/r, 1060→1053 r/r.
  Details: `session_logs/2026-07-14_g01_clocking_blocks.md`.
- **Next (M8 increment 2)**: real clocking semantics — input sampling
  (#1step history / #0 Observed) and synchronous drives (Re-NBA),
  replacing the alias rewrites for all scopes at once on the M6 region
  entry points; then `cb.sig <= ##N v` drives. See the session log's
  "Next engineering step". G05/G06 (SVA) remain the M9 entry.

## State as of 2026-07-14h (session: M6 COMPLETION — trampoline default + scheduled-path deletion)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (fresh from
  merged main after PR #71; new PR to open for this work).
- **This checkpoint completes M6**:
  - **Increment 3**: flipped the callf default to the trampoline
    (`IVL_TRAMPOLINE_CALLF=0` = legacy synchronous fallback).  Full
    default-config battery clean (UVM 127/127, ivtest baseline-identical,
    vpi 85/85, py 284/12).  The default subroutine-call model now
    preserves function-call atomicity (IEEE 13.4.3) and bounds C++ stack
    depth by the `vthread_run` loop, not SV call depth.
  - **Increment 4**: deleted the BROKEN scheduled-call path
    (`IVL_SCHED_CALLF`, `sched_callf_enabled_`, `schedule_defer_calls_ok`,
    `sched_main_loop_running`) — proven incorrect by the atomicity
    finding, so dead/wrong code.  RETAINED (one-release fallback) the
    synchronous drain loops + staging + limit maps behind
    `IVL_TRAMPOLINE_CALLF=0`.
  - Details: `session_logs/2026-07-14_m6_completion.md`; rearchitecture
    doc increments 3-4 recorded.
- **M6 STATUS: functionally complete.**  All five remediation items
  delivered (region tagging/invariants; reactive regions; slot-persistent
  event.triggered/G08; Preponed/Observed; atomicity-correct trampoline
  call model as default).  Sole remaining item is code hygiene — deleting
  the retained synchronous fallback + staging heuristics after a release
  soak (no behavior/capability change).
- **Next milestone**: M8 (clocking blocks) or M9 (core SVA engine) — both
  now have their scheduler foundation (region tags/invariants,
  Preponed/Observed entry points, atomicity-correct calls).  G01 (clocking
  outside interface, hard crash) and G05/G06 (SVA sequence operators) are
  the gap-audit entry points.

## State as of 2026-07-14g (session: M6 item 5 rearchitecture increment 2 — trampolined callf)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #71 open,
  draft — new PR after #70 merged; stacks the rearchitecture on it).
- **This checkpoint**: implemented the **trampolined synchronous call**
  behind `IVL_TRAMPOLINE_CALLF` (default OFF).  `%callf` switches the
  `vthread_run` inner loop to the callee frame (push caller +
  `trampoline_switch_to`) and back when the callee ends (keyed on
  `rc==false && is_trampoline_child && i_have_ended`, since functions
  end via `%disable/flow` not `%end`), reaping via `do_join`.  No
  recursive `vthread_run` → C++ stack depth bounded by the loop, not SV
  call depth.
- **KEY RESULT**: under the flag the trampoline reaches FULL parity —
  UVM **127/127**, ivtest failure names **byte-identical** to baseline
  (incl. `pr2001162`/`pr2053944` which the scheduled path FAILED) — AND
  the atomicity suite PASSES (the scheduled path failed it).  So the
  trampoline, unlike the scheduled path, is a viable replacement: it
  preserves function-call atomicity AND removes the C++-stack
  constraint.  Default (flag OFF) unchanged (validated by the default
  battery).  Details:
  `session_logs/2026-07-14_m6_trampoline_callf.md`; rearchitecture doc
  increment 2 marked DONE.
- **Known limitation**: `do_join`'s automatic-context reconciliation is
  O(depth); recursion beyond a few thousand frames is O(depth²) slow
  (still deeper than the sync model's 4096 cap) — a perf follow-up.
- **Next (increment 3)**: flip the default to the trampoline (its own
  checkpoint, highest-risk), then delete the three synchronous drain
  loops + the automatic-context staging in `do_callf_void`; increment 4
  deletes the now-unused limit maps.  That completes step 5 and M6.

## State as of 2026-07-14e (session: M6 item 5 step 3 — parity + fundamental blocker)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #70 open,
  draft).
- **This checkpoint**: pursued scheduled-call parity (step 3) toward the
  default flip (step 4).  (a) Added the init/final-phase guard
  `schedule_defer_calls_ok()` — the scheduled branch falls back to
  synchronous execution outside the main event loop (init/final/rosync
  phases, which are sequential); this fixed the sole UVM divergence
  (`static_init_order_test`) → **UVM 126/126 under the flag**.  (b) The
  full ivtest corpus under the flag then exposed a FUNDAMENTAL blocker:
  the suspend-caller design violates function-call atomicity (IEEE
  13.4.3), so two concurrent calls interleave — `pr2001162` (shared
  counter read-modify-write no longer atomic) and `pr2053944` (two
  concurrent static-function calls cross-contaminate the shared return:
  `v1=1 v2=2` → `1 1`).  **Steps 4-5 are BLOCKED**: flipping the default
  would introduce silent miscompiles.  The scheduled path stays behind
  `IVL_SCHED_CALLF` (default OFF), so all default behavior is unchanged.
  Blocker pinned by `tests/m6_call_atomicity_test.sv` (PASS on default,
  FAIL under flag).  Details:
  `session_logs/2026-07-14_m6_scheduled_callf_step3.md`; protocol doc
  steps 3-5 revised.
- **Revised next target (M6 item 5)**: redesign the callee to run inline
  as a scheduler-tracked frame WITHOUT yielding the active region (the
  caller stays the running thread; the callee frame is driven to
  completion before any sibling active event runs), which preserves
  atomicity — then retry the flip.
- **Regressions**: default (flag OFF) unchanged; recorded in the commit.

## State as of 2026-07-14d (session: M6 item 5 step 2 — scheduled-call path behind a flag)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #70 open,
  draft — stacks onto the item-5 characterization checkpoint).
- **This checkpoint**: implemented the scheduled-call protocol behind
  `IVL_SCHED_CALLF` (default OFF).  In `do_callf_void`
  (`vvp/vthread.cc`), once the callee frame + automatic context are set
  up, the scheduled branch schedules the callee to the front of the
  Active region and returns false to suspend the caller; the callee's
  `%ret` fills the caller's frozen return slot and its `%end` resumes
  the caller through the existing `of_END` ->
  `resume_joining_parent_` -> `do_join` join machinery (output/ref
  mirroring + reap reused unchanged).  `sched_callf_enabled_()` gates
  it; flag OFF is byte-identical to the synchronous model.  The full
  characterization suite passes under the flag, and `vif_smoke` (a UVM
  test) also passes under the flag with zero errors.  Details:
  `session_logs/2026-07-14_m6_scheduled_callf_step2.md`; protocol doc
  migration plan step 2 marked DONE.
- **Regressions**: flag-OFF battery recorded in the checkpoint commit.
- **Remaining item-5 steps**: 3 (full focused-M6 + UVM-subset parity
  under the flag; make the nested-caller resume fully async), 4 (flip
  the default — its own checkpoint), 5 (delete the synchronous drain
  loops + per-callsite/edge/scope/depth limits + UVM-identifier
  special-casing).  That completes M6.

## State as of 2026-07-14b (session: M6 item 4 — Preponed + Observed regions)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #70 open,
  draft — stacks onto item 1's checkpoint).
- **This checkpoint**: added the Preponed and Observed regions
  (`vvp/schedule.cc`, `vvp/schedule.h`).  `SEQ_PREPONED` drains at slot
  entry before Active (IEEE 4.4.2.1 sampling); `SEQ_OBSERVED` is
  promoted into active after NBA, before the reactive set (4.4.2.4
  concurrent-assertion evaluation).  New `event_time_s` queues, switch
  cases, region names, run_rosync leftover check, and header-exported
  entry points `schedule_at_preponed` / `schedule_at_observed` for the
  future SVA/clocking engines.  No consumers yet — this is the
  foundation.  Ordering proven by the `IVL_REGION_SELFTEST` injection
  (reverse insert drains Preponed→Active→NBA→Observed→Reactive→Re-NBA→
  RWSync→ROSync).  Details:
  `session_logs/2026-07-14_m6_preponed_observed.md`; audit region table
  + remediation item 4 marked DONE.
- **Tests**: `tests/m6_region_trace/run_region_trace.sh` extended
  (part 2 asserts the full self-test region order).
- **Regressions**: recorded in the checkpoint commit message.
- **Remaining M6 tail**: item 5 only — replace the `%callf`
  synchronous-drain assumption with an explicit scheduled-call protocol
  (largest/riskiest; characterization tests first).

## State as of 2026-07-14 (session: M6 item 1 — event region tagging)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #70 open,
  draft — this checkpoint stacks onto it).
- **This checkpoint**: first scheduler-remediation priority done.
  Every `event_s` now carries an IEEE 1800-2017 clause-4 region tag
  (`event_queue_t region`, stamped by `schedule_event_` /
  `schedule_event_push_`).  `region_enter_` (env `IVL_REGION_TRACE=1`)
  prints `REGION @ <time> ps <region>: <event>` at each run site (main
  active loop, Start drain, ROSync/DelThread drains) — the tag rides on
  the event so wholesale-promoted events report their TRUE region,
  making item 2's promotion approximation observable.
  `region_check_schedule_` asserts the one hard LRM invariant (4.4.2.10:
  read-only ROSync region may only create ROSync/thread work), warning
  by default and aborting under `IVL_REGION_ASSERT=1` (audit point 9,
  previously absent).  All env-gated: no behavior change or overhead in
  normal runs.  Details:
  `session_logs/2026-07-14_m6_region_tagging.md`; audit doc remediation
  item 1 marked DONE.
- **Tests**: `tests/m6_region_trace/run_region_trace.sh` (new; asserts
  the trace emits all four regions in stratified order).
- **Regressions**: recorded in the checkpoint commit message.
- **Remaining M6 tail**: item 4 (Preponed/Observed regions — SVA/
  clocking prerequisite; the enum/tag/trace now give it a landing spot
  and an invariant harness); item 5 (scheduled-call protocol to retire
  the `%callf` synchronous-drain heuristics — largest/riskiest).

## State as of 2026-07-13h (session: indexed-element container methods)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #70 open,
  draft — this checkpoint stacks onto it).
- **This checkpoint**: container method calls on INDEXED-ELEMENT
  receivers (`aq[k].size()`, `qa[i].num()`, `aa[k].exists(x)`,
  `aq[k].pop_back()`, `qa[i].delete(key)`) were compile-progress
  stubs (constant 0 / null / silent positional mis-delete).  Three
  fixes: (1) `elaborate_method_dispatch_` now dispatches on the
  element type when an indexed receiver's element is itself a
  container (7.12 applies to any unpacked array expression; the
  lowering already handles object-stack receivers); (2) the
  `PECallFunction::test_width` indexed branch mirrors the container
  method table — previously pop_back/find fell to the class-null stub
  type and `elab_and_eval` constant-folded the call to 0 in scalar
  ASSIGNMENT contexts before elaborating (display contexts worked,
  which hid the bug); (3) keyed delete on assoc elements emits
  `%aa/delete/<kind>` through the element handle (was positional
  `%delete/o/elem` — silent no-op).  BONUS general fix: exists()
  built its result as an all-ones vector on every receiver shape —
  `aa.exists(k) + 1` evaluated to 0; 7.9.3 requires 1/0 (all four
  runtime helpers now LSB-only).
- **Tests**: `tests/g09_elem_methods_test.sv` (32 checks).
- **Regressions**: recorded in the checkpoint commit message.
- **Remaining G09 tail**: 3-deep chains; object-valued chained reads
  in object context; darray (`new[]`) outers in the store2 rewrite.

## State as of 2026-07-13g (session: G09 completion)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #70 open,
  draft — this checkpoint stacks onto it).
- **This checkpoint** closes the G09 tail:
  (1) inner ASSOCIATIVE foreach dimensions (12.7.3) — the first/next
  key descent now works at any dimension depth
  (`elaborate_assoc_array_` gained `index_var_start`; the counting
  loop descends into it), so `foreach (aa[k1,k2])` and
  `foreach (qa[i,k])` iterate;
  (2) chained keyed reads through POSITIONAL outers
  (`qa[0]["a"]`) — the eval_vec4/eval_string root-derivation guards
  accepted only assoc-compat roots; now any queue/darray root
  supplies the element type (the keyed branch still requires the
  ELEMENT to be assoc-compat);
  (3) chained element stores for ALL four outer/inner combinations —
  `aq[k][i]=v` was a SILENT NO-OP and `qa[i][k]=v` / `qq[i][j]=v`
  CLOBBERED the row; the `$ivl_assoc$store2` rewrite now fires for
  any queue-typed outer with container elements (static-array
  signals excluded) and the lowering picks keyed-viv vs positional
  outer access and keyed vs positional inner store; NEW opcodes
  `%store/qo/i/{v,r,str,obj}` (indexed store through an object-stack
  queue receiver, set_word_max semantics);
  (4) value semantics (7.6/7.9.9): element stores of container
  values used to alias the source handle — `container_value_copy_`
  duplicates darray/queue/assoc values at every object-valued
  element-store site (class handles still alias; %aa/viv untouched).
  Details: `session_logs/2026-07-13_g09_completion.md`.
- **Tests**: `tests/g09_nested_container_test.sv` extended to 34
  checks (inner-assoc foreach, queue-of-assoc reads/stores, all four
  store shapes with neighbor preservation, copy semantics).
- **Regressions**: recorded in the checkpoint commit message.
- **Remaining G09 tail**: `aq[k].size()` expression-context method
  stubs; 3-deep chains; object-valued chained reads in object
  context; darray (`new[]`) outers in the store2 rewrite.

## State as of 2026-07-13f (session: G09 nested dynamic containers)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #70 open,
  draft — this checkpoint stacks onto it).
- **This checkpoint**: G09 root-caused to THREE layered defects and
  fixed: (1) unpacked dimension lists composed left-to-right, so
  `int aq[int][$]` was a queue-of-assoc (7.4.5/20.7 require
  right-to-left; every mixed nested declaration was silently wrong);
  (2) `aa[k1][k2] = v` dropped the inner key — now the internal
  `$ivl_assoc$store2` task + new auto-vivifying `%aa/viv/{sig,o}/{v,str}`
  opcodes (spec codes 0-7) + keyed stores through the element handle;
  (3) chained reads lowered positionally — now keyed loads (vec4 +
  string contexts; net_type derived from the root signal for chained
  selects).  assoc-of-queue mutation + 2D foreach (uvm_resource_pool
  shape) and assoc-of-assoc chained stores/reads (report_server/
  printer/recorder shape) verified.  Inner-assoc foreach dimension:
  explicit sorry (was silent-0, briefly a hang mid-fix).
  Details: `session_logs/2026-07-13_g09_nested_containers.md`.
- **Tests**: `tests/g09_nested_container_test.sv` (15 checks).
- **Regressions (final, quiet machine)**: UVM **124/124**; ivtest
  vvp_reg.pl 2961/3101 with failure names byte-identical to baseline;
  negative 6/6; all focused suites (g10 ×3, g68, g69, m6, g12, m3)
  PASS.  The WIP commit 55b31fe is hereby promoted — the global
  dimension-composition change is regression-clean.
- **Remaining G09 tail**: inner-assoc foreach dimension (first/next
  descent, key-typed loop vars); `aq[k].size()` expression-context
  method stubs; 3-deep chains; object-valued chained reads.

## State as of 2026-07-13e (session: 7.12.4 iterator index querying)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #70 open,
  draft — this checkpoint stacks onto it).
- **This checkpoint**: IEEE 1800-2017 7.12.4 — `item.index` (and the
  index()/index(1) call forms) now resolves to the enclosing array
  method's loop counter in all with-expression contexts
  (find*/reductions/min-max/sort/rsort; custom iterator names;
  class-property receivers; nested with expressions including outer
  index from inside inner).  Mechanism: nesting-safe iterator context
  stack (elab_expr.cc, API in netmisc.h) pushed around predicate
  elaboration in all four loop builders; PEIdent + PECallFunction
  interceptions.  dimension != 1 → sorry.  Bonus general fix exposed
  en route: test_width reported width 0 for reductions used as
  operands (`q.sum() + 1` evaluated to 0 — operands padded to zero
  bits); now element width (no with) / int approximation (with).
  Details: `session_logs/2026-07-13_g10_iter_index.md`.
- **Tests**: `tests/g10_iter_index_test.sv` (19 checks incl. the
  7.12.4 LRM literal example `arr.find with (item == item.index)`).
- **Remaining 7.12 tail**: unique on non-queue receivers;
  assoc/multidim receivers; fixed-array class properties; ordering on
  fixed arrays; index on non-zero-based fixed ranges / dimension > 1.

## State as of 2026-07-13d — PR #69 MERGED (424a6bc); branch restarted

- **PR #69 is MERGED and FINAL** (merge commit 424a6bc on main): all
  five checkpoints (M6 Reactive regions, G10 reductions/min-max, G10
  property receivers, G68 process.status + G69 inside precedence,
  7.12.2 ordering methods).  Do not reopen; follow-up work gets a NEW
  draft PR.
- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` restarted
  from origin/main at 424a6bc (force-with-lease over the
  already-merged history per protocol).
- **Next options**: M6 item 1 (region tagging + trace — unlocks exact
  region-priority popping) or 4 (Preponed/Observed stubs) or 5
  (scheduled-call protocol); `item.index` (last gap-audit-cited 7.12
  breakage); G12 tail (with[range], continuous-assign lvalues,
  struct/class operand flattening); unique on non-queue receivers;
  G09 (2D assoc foreach); G66.

## State as of 2026-07-13c (session: 7.12.2 ordering methods)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #69 open,
  draft).
- **This checkpoint**: three defects in the sort/rsort/reverse/
  shuffle/unique statement paths (IEEE 1800-2017 7.12.2): instance-
  property receivers silently NO-OP'd (explicit skip in
  tgt-vvp/vvp_process.c — now hidden-recv-net pattern, matching the
  expression-side G10 work); with-clause sort keys always truncated
  to int32 (string keys — the UVM `sort() with (item.get_full_name())`
  shape in uvm_cmdline_report/uvm_root/uvm_phase_hopper — silently
  mis-sorted past a shared 4-byte prefix; keys now typed
  string/real/sb32 end to end); shared iterator-net poisoning in the
  sort_with elaboration (now fresh nets + set_signal_alias).
  Runtime: qsort/qunique keys helpers generalized over key type — no
  new opcodes.
  Details: `session_logs/2026-07-13_g10_ordering_methods.md`.
- **Tests**: `tests/g10_ordering_methods_test.sv` (28 checks).
- **Remaining 7.12 tail**: unique on non-queue receivers;
  assoc/multidim receivers; `item.index`; fixed-array class
  properties; ordering methods on fixed-size arrays.

## State as of 2026-07-13b (session: G68 process.status + G69 inside precedence)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #69 open,
  draft).
- **Regression alert resolved**: checkpoint c6e8206 (property
  receivers) turned seq_trace_test / vif_smoke / vif_smoke_v2 red
  (SEQLCKZMB@0 + PH_TIMEOUT@9200) by making the UVM sequencer zombie
  predicate execute for the first time, exposing TWO pre-existing
  latent defects, both now fixed:
  - **G68**: `process::status()` read a dead stored property (always
    0 = FINISHED per 9.7) — now a live query via new vvp opcode
    `%process/status` (call form + paren-less property-chain form +
    stub-classifier exemption + module-scope process:: enum
    constants).
  - **G69**: `inside` sat at ternary precedence; Table 11-2 puts it
    at the relational level — `a && b inside {c,d}` mis-parsed as
    `(a && b) inside {c,d}`, so `(0) inside {KILLED, FINISHED=0}`
    matched every non-lock arbitration entry.  K_inside moved to the
    relational %left group (conflicts unchanged 459/1060).
  Details: `session_logs/2026-07-13_g68_g69_process_status_inside_precedence.md`.
- **Tests**: `tests/g68_process_status_test.sv`,
  `tests/g69_inside_precedence_test.sv`.
- **Known approximation**: delay-suspended processes read RUNNING;
  SUSPENDED never reported (no suspend()/resume()).

## State as of 2026-07-13 (session: G10 tail — class-property receivers)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #69 open,
  draft; CI green on all 6 platforms at def4cf7 before this
  checkpoint).
- **This checkpoint**: array reduction/min-max/find* methods now work
  on CLASS-PROPERTY receivers — the dominant UVM shape
  (`this.q.sum()` in scoreboards, `cfg.st.q.max()` nested chains,
  external `obj.q.sum()`, paren-less `return q.sum;`).  Mechanism: a
  non-signal object receiver is evaluated once and its handle stored
  into a hidden container-typed net that the existing inline loop
  indexes through (extra trailing sfunc parm; tgt-vvp
  `draw_array_method_recv_`).  The PEIdent class-property tail path
  that previously WARNED AND SILENTLY DROPPED the expression
  (`Array method 'sum' on class-property darray/queue not yet
  supported ... expression dropped`) now routes to the same
  machinery.  Fixed-size-array class properties: explicit sorry.
  Details: `session_logs/2026-07-13_g10_property_receivers.md`.
- **Tests**: `tests/g10_array_methods_test.sv` extended to 43 checks
  (class-property section: method-internal, external, nested-chain,
  paren-less, with-clause, locators, empties).
- **G10 tail remaining**: sort/rsort/reverse/shuffle (7.12.2); unique
  on non-queue receivers; assoc/multidim receivers; `item.index`;
  fixed-size-array class properties.

## State as of 2026-07-12e (session: G10 array reduction methods)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #69 open,
  draft — this checkpoint stacks onto it; head before this checkpoint
  was 9f7c918, the ivl.def Windows export fix).
- **This checkpoint**: G10 — IEEE 1800-2017 7.12.3 array reduction
  methods (`sum`/`product`/`and`/`or`/`xor`) and 7.12.1
  `min()`/`max()` implemented over queues, dynamic arrays and 1-D
  fixed-size unpacked arrays, in all four source forms (call,
  call+with, paren-less, paren-less+with) including the keyword-named
  `.and()/.or()/.xor()` (new grammar rules, +6 documented s/r
  conflicts 453→459).  `find*` locators extended to dynamic/fixed
  arrays.  Result width/signedness follow the with expression
  (7.12.3).  New `NetScope::set_signal_alias` gives each call its own
  iterator binding (7.12 "scope for the iterator_argument is the with
  expression") — also fixes a pre-existing find_with bug where sibling
  calls with different element types shared one hidden `item` net
  (signed/width poisoning; could trip a vvp store assertion).  Runtime
  is inline vvp loops from EXISTING opcodes only
  (`$ivl_darray_method$reduce|`/`minmax|` lowered in tgt-vvp).
  Explicit `sorry` diagnostics (no silent fallbacks) for assoc-array
  and multidimensional receivers and string/real min/max.
  Details: `session_logs/2026-07-12_g10_array_reduction_methods.md`.
- **Tests**: `tests/g10_array_methods_test.sv` (29 checks incl. all
  7.12.3 LRM literal examples);
  `tests/negative/g10_reduction_non_integral.sv` (negative suite now
  6/6).
- **G10 tail remaining**: sort/rsort/reverse/shuffle (7.12.2); unique
  on non-queue receivers; assoc/multidim receivers; `item.index`;
  class-property receivers (still on the older PEIdent property path).

## State as of 2026-07-12d (session: M6 item 2 — Reactive region)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy`, restarted from
  merged main (PR #68 merged with G67 + G12 static/dynamic streaming —
  do not reopen; this checkpoint gets a NEW draft PR).
- **This checkpoint**: M6 scheduler remediation item 2 — program-block
  processes now schedule in the Reactive region set (IEEE 1800-2017
  4.4.2.5/.6/.7, clause 24): new vvp slot queues reactive/re-inactive/
  re-nbassign with LRM promotion order; per-thread reactive flag from
  the new `.scope program` type (plumbed via new ivl_scope_program API),
  inherited by spawned children; program #0 → Re-Inactive; program NBAs
  → Re-NBA; event wake chains PARTITIONED by region (a shared functor
  previously dragged all waiters into one region).  Both elaborate.cc
  program-scheduling compile-progress warnings retired.  Programs now
  sample post-NBA design state race-free.
  Details: `session_logs/2026-07-12_m6_reactive_region.md`.
- **Tests**: `tests/m6_reactive_region_test.sv` (4 region orderings).
- **Regressions**: UVM 118/118 (+1 new test); ivtest 2961/3101 with the
  same 132 pre-existing fails (baseline-identical).
- **Known approximation** (recorded in scheduler audit): wholesale
  queue promotion (pre-existing model) — exact region-priority popping
  is item 1's region-tagging work.
- **Next options**: M6 items 1 (region tagging + trace) / 4
  (Preponed/Observed stubs) / 5 (scheduled-call protocol); G12 tail
  (struct operand flattening, with[range]); M3 tail; G66; G09/G10.

## State as of 2026-07-12c (session: G12 tail — dynamic-size streaming)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #68 open,
  draft — three checkpoints stacked).
- **This checkpoint**: dynamic-size streaming operands/targets
  (11.4.14.4) implemented via a vvp runtime stream builder — new
  opcodes `%stream/flatten/{obj,str}`, `%stream/end/{l,r}`,
  `%stream/unpack/{l,r}`, `%stream/to/{queue,dar}`, plus
  `get_bitstream` overrides for queue/string containers.  Both UVM
  idioms verified end to end (uvm_reg_map byte<->bit queue pair
  round-trips bit-exactly; uvm_misc string-queue join).  Previously
  all these shapes compiled cleanly with silent wrong data.
  Unsupported dynamic contexts now error with clause references.
  Details: `session_logs/2026-07-12_g12_dynamic_streaming.md`.
- **Tests**: `tests/g12_streaming_dynamic_test.sv`.
- **G12 tail remaining**: `with [range]`, continuous-assign streaming
  lvalues, struct/class operand flattening, class-property container
  operands, multi-operand dynamic unpack.

## State as of 2026-07-12b (session: G12 streaming concatenation)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #68 open,
  draft — this checkpoint stacks onto it).
- **This checkpoint**: G12 fixed for fixed-size integral operands —
  multi-operand streaming concatenation pack AND unpack (IEEE
  1800-2017 11.4.14/.1/.2/.3), removing the parse.y fallback family
  that silently dropped operands.  Semantics grounded in the published
  LRM text and its literal examples (all in the permanent test).  Key
  subtleties implemented: unpack is the INVERSE of the `<<` reorder
  (differs from forward when slice ∤ width), wider unpack sources are
  consumed from the left, pack-as-assignment-source is LEFT-aligned
  with error on narrower targets, slice sizes (expressions/types)
  resolve at elaboration.  Details:
  `session_logs/2026-07-12_g12_streaming_concatenation.md`.
- **Tests**: `tests/g12_streaming_concat_test.sv` (+2 negative tests).
- **G12 tail (recorded in gap audit)**: dynamic-size operands
  (queues/darrays/strings, 11.4.14.4 — needed by uvm_reg_map byte
  packing), `with [range]`, continuous-assign streaming lvalues,
  struct/class operand flattening.

## State as of 2026-07-12 (session: G08 event.triggered + G67 process identity)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy`, restarted from
  merged main (`439ba47`, PR #67 merged — do not reopen; new work gets a
  NEW draft PR).
- **This checkpoint**: G08 `event.triggered` (IEEE 1800-2017 15.5.3) is in
  main via PR #67; the two UVM regressions it exposed
  (`vif_smoke`/`vif_smoke_v2` PH_TIMEOUT) were root-caused to **G67**:
  `vthread_new` never initialized `is_fork_v_child`, so
  `process::self()` inside fork...join_none blocks could alias an ancestor
  process (heap-garbage dependent), and UVM's phase kill then destroyed
  sibling phase processes (driver run_phase died mid sequencer handshake).
  Fix: one line in `vvp/vthread.cc` (`thr->is_fork_v_child = 0;`).
- **Evidence**: byte-identical compiled images differing in one label
  string flipped hang/pass pre-fix; the previously-failing image passes
  unmodified on the fixed runtime. Full chain in
  `session_logs/2026-07-12_event_triggered_g67_process_identity.md`.
- **Tests added**: `tests/m6_process_identity_test.sv` (+ G08's
  `m6_event_triggered_test.sv` from the merged PR).
- **Gap audit**: G08 FIXED, G67 NEW+FIXED (docs/claude gap audit updated).
- **Next recorded options** (unchanged priority list): M6 remediation items
  1/2/4/5 (region tagging + trace hook; Reactive region for program
  blocks; Preponed/Observed stubs; scheduled-call protocol replacing callf
  synchronous-drain heuristics — G67 is more evidence this area needs it);
  M3 tail (dynamic-array foreach, solve...before staged ordering,
  non-0-based foreach ranges); M4 container runtime; M5
  interfaces/modports; G66 root-cause.

## State as of 2026-07-11 (session: typed-expression dispatch)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy`
- **Latest pushed commit**: `51c0d94` (checkpoint 2 — M1 implementation, tests, vvp fix)
- **Pull request**: https://github.com/dsellerbrock/iverilog-uvm/pull/66 (draft; CI watched)
- **Final regression evidence**: UVM 104/104; ivtest byte-identical to pristine
  baseline (vvp_reg 2961/3101 + same 132 pre-existing fails, vpi 85/85,
  vvp_reg.py 284/12); make check pass; negative suite 2/2.
- **Selected feature**: Manifesto M1 — typed-expression method dispatch
  (gaps G22, G31, G32 + latent vvp same-scope frame bug)
- **Governing IEEE clauses**: 1800-2017 8.10 (object methods), 6.19.5 (enum
  methods), 8.23 (class scope resolution), 8.25 (parameterized classes),
  13.4.1 (void functions / discarded results)

## Completed this session

1. Manifesto imported at `docs/conformance/iverilog_ieee1800_uvm_manifesto.md`.
2. Baseline: clean build + 98/98 canonical UVM regression at `a014332`.
3. **Parser** (`parse.y`):
   - `expr_primary '.' IDENTIFIER/TYPE_IDENTIFIER argument_list_parens` no
     longer deletes the receiver: PEIdent receivers splice into a
     hierarchical path (behavior-preserving); all other receivers become
     receiver-carrying `PECallFunction`s.
   - New `subroutine_call` alternatives for statement-context chains:
     `f(args).m(args);`, `C::get(args).m(args);`, `C#(p)::get(args).m(args);`
     (+2 shift/reduce conflicts, resolved by shift = the new rules; baseline
     448 → 450 s/r, r/r unchanged at 1060).
4. **AST**: `PECallFunction` and `PCallTask` carry an optional `receiver_`
   expression (`PExpr.h/cc`, `Statement.h/cc`, `pform_dump.cc`).
5. **Elaboration** (`elab_expr.cc`):
   - Extracted the method-dispatch tail of `elaborate_expr_method_` into
     shared `elaborate_method_dispatch_(sub_expr, target_type, ...)`.
   - New `elaborate_receiver_method_` elaborates the receiver, takes its
     exact `net_type()`, and dispatches (class methods incl. inherited &
     specialized, enum methods, string/queue/darray methods).
   - `PECallFunction::test_width` handles receiver calls (mirrors
     `PEMemberAccess::test_width`).
   - `PCallTask::elaborate_receiver_method_` (`elaborate.cc`): class-typed
     receivers; void methods/tasks via `elaborate_build_call_`; non-void
     via PAssign-to-nothing re-expression.
6. **vvp runtime fix** (`vvp/vthread.cc`,
   `vthread_get_rd_context_item_scoped`): after a callf join, the returned
   child frame (rd-head, no longer in the wt chain) now takes priority over
   a same-scope pre-%alloc'd caller frame at wt-head. Fixes nested calls of
   the SAME function (builder chains `c.f(...).f(...)`, `f(g(f(x)))`).
   **This bug pre-existed this session's work** — confirmed by pristine
   baseline build failing the reduced probe.
7. **Tests added** (committed to `tests/`):
   - `m1_method_on_call_result_test.sv` (f().method(), f().prop, void stmt)
   - `m1_method_chain_builder_test.sv` (chains + nested same-method)
   - `m1_enum_method_chain_test.sv` (enum_f().name(), c.next().name(), …)
   - `m1_static_accessor_chain_test.sv` (S::get().m(), P#(T)::get().m(), stmt)
   - `m1_uvm_factory_by_name_test.sv` (G22 unmodified-UVM flow)
   - `tests/negative/` + `run_negative.sh` (unknown method on call result,
     unknown enum method → controlled diagnostics)

## Tests currently passing

- All six reduced probes (originally 5 failing shapes).
- UVM factory by-name probe (G22 canonical path) — PASS.
- Negative suite 2/2.
- Canonical regression: rerun in progress at last update (baseline was 98/98).

## Known limitations / follow-ups

- Statement-context chains cover single-hop `<call>.method(args);` for the
  three grammar shapes above. Multi-hop statement chains
  (`f().m1().m2();`) and receiver forms starting from casts/selects in
  statement position are not yet parsed. Expression context covers
  arbitrary depth.
- Diagnostics for failing receiver calls print twice (test_width +
  elaborate double elaboration — same pre-existing pattern as
  PEMemberAccess).
- Non-class receivers in statement context get a clean `sorry`.
- `with`-clause locator methods on receiver calls parse to PENull
  (pre-existing parser fallback, unchanged).

## Checkpoint 4 (M3) — regression-clean, PR #67

- **G15/G17/G18/G20 FIXED + G11 implication half**: constraint implication,
  if-else sets, enum-literal sets, inheritance merge, and solver arithmetic
  (impl/iff/add/sub/mul/div/mod). See session log checkpoint 4.
- PR #66 (M1+M2) was MERGED into main; branch restarted from merged main.
- M3 work on PR #67 (draft): WIP commit `9d64dda` + regression-confirmation
  docs commit.
- Regressions: UVM **110/110**; ivtest **byte-identical to baseline**
  (2961/3101+132, 85/85, 284/12); make check pass.

## Checkpoint 5 (M3 increment 2) — regression-clean

- **G21 FIXED**: `arr.size()` → solver size var `s:N:T`; darray created/
  resized at write-back (cap 65536), elements filled randomly.
- **G16 FIXED (static arrays)**: PEConstraintForeach + compile-time unroll
  with loop-var env; element vars `e:N:W:I` solved and written back;
  %randomize now fills static-array rand property elements.
- **Hang fixed**: solver inside/dist range parser now expression-capable
  and always makes forward progress (previously hung on compound ranges).
- Focused: single-shot probes + 10-iteration probe + permanent test
  `tests/m3_constraint_array_test.sv` all PASS. UVM regression
  **111/111**; ivtest **byte-identical to baseline**. WIP marker on
  6f7e875 superseded by the regression-confirmation docs commit.

## Checkpoint 6 (M3 tail: signed comparisons) — regression-clean

- Unary minus folded to two's complement (was silently dropped);
  signed p:/e: markers; bvslt-family + sign extension per IEEE
  1800-2017 11.8.1; signed inside/dist ranges.
- Test `tests/m3_constraint_signed_test.sv`. UVM **112/112**; ivtest
  **byte-identical to baseline**. WIP 889d084 superseded.

## Checkpoint 7 (M6 scheduler audit) — docs + litmus regressions

- `docs/conformance/scheduler_audit_2026_07.md`: queue inventory
  (start/active/inactive/nbassign/rwsync/rosync/del_thr + init/final
  lists), IEEE 4.4.2 region mapping (Preponed/Observed/Reactive ABSENT),
  implicit-ordering inventory (%fork push_flag, insertion-order
  dependence), direct-execution findings (callf synchronous drains and
  the staged-context heuristics), event-trigger lifetime (G08),
  VPI callback mapping, end-of-slot behavior, and a 5-step remediation
  priority list for M6 implementation.
- `tests/m6_sched_litmus_test.sv`: NBA-vs-blocking, #0 inactive, and
  $strobe postponed-region orderings as durable characterization
  regressions (PASS).

## Exact next actions

1. Watch PR #67 CI.
2. M6 implementation per the audit's remediation priorities: (1) region
   tagging + trace hook, (2) Reactive region for program blocks,
   (3) slot-persistent event.triggered (G08), (4) Preponed/Observed
   stubs, (5) scheduled-call protocol replacing callf sync drains.
3. Remaining M3 tail: dynamic-array foreach, `solve...before` staged
   ordering, non-0-based array ranges.
4. Alternatives: M4 container runtime, M5 interfaces/modports, G66.

## Manifesto v2 alignment review (2026-07-11)

The governing manifesto was updated to v2 (commit c2e53d3). Review of this
session's M1-M3 implementations against v2:

- **Semantic IR remediation**: the M1 receiver-dispatch work matches v2's
  prescribed migration entry point (expression and member-access
  semantics). `elaborate_method_dispatch_` is the shared typed-expression
  dispatch interface; return types flow through `NetEUFunc(net_type)`.
- **Code-pattern scan** of the full session diff: no added TODO/FIXME,
  no compile-progress fallbacks, no UVM identifier checks; one explicit
  `sorry` diagnostic (non-class receivers in statement context) per
  manifesto principle 4.
- **Tracked diagnostics added** (v2: "convert silent type-recovery
  fallbacks into tracked diagnostics"): unrepresentable-constraint-item
  warning; uarray shape-mismatch errors.

### Architectural debt register (v2 Risks)

1. **PEIdent path-splice adapter** (parse.y receiver rules): legacy
   name-based lookup retained for identifier receivers. Acceptable
   adapter now; must not become a permanent duplicate dispatch path
   (fold into receiver dispatch when the semantic IR migration reaches
   name resolution).
2. **test_width double-elaboration** (receiver calls, PEMemberAccess
   pattern): duplicate diagnostics; symptomatic of missing typed
   expression interface (v2 Risk 4).
3. **vvp automatic-context heuristics** (`staged_alloc_rd_*`,
   `skip_free_*`, chain-membership fix): the returned-frame fix is
   correct but the surrounding machinery relies on implicit ordering —
   squarely in v2's scheduler remediation program scope (M6 audit item 4/5:
   direct thread execution + synchronous-child assumptions in callf).
4. **Constraint IR is string-based S-expressions** with unsigned-only
   comparisons and scalar-only properties: adequate for current gaps,
   but array/signed/ordering support (G16/G21) will strain it; consider
   a typed constraint IR when extending.
5. **Pre-existing compile-progress fallback inventory** (45 sites,
   audit section) remains open — Phase 75 scope.

## Decisions not to revisit without new evidence


- Receiver dispatch reuses `elaborate_method_dispatch_` — do NOT fork a
  second dispatch path for receiver calls.
- PEIdent receivers in the changed parser rules must keep path-splicing
  (preserves package/implicit-this resolution semantics).
- The vvp fix keys on "rd-head live for scope AND absent from wt chain";
  the %alloc staging window keeps wt-head priority because the caller
  frame is still chained in wt. Both cases are exercised by
  `m1_method_chain_builder_test.sv`.
