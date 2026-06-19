# Fallback Inventory

> **Re-verified 2026-06-19 @ Phase 87 (`60c7a2eb5`).** sv-tests 1027/1027 with 0 WARN-PASS
> (no *sampled* test is silently degraded), but the **Active Fallbacks** below still exist on
> un-sampled UVM-runtime paths and remain the honesty risk. This is an internal engineering
> checklist — see `IEEE1800_UVM_SUPPORT.md` for the public-facing status. The current #1
> runtime gap (OpenTitan plateau) is the `wait(assoc[k].class_member)` event-propagation bug
> documented in `IEEE1800_UVM_SUPPORT.md` §2.3, not one of the stubs listed here.

Use this file as the first check on every new frontier. Before treating a failure as a new SV/UVM bug, grep the current compile/run logs for the warning signatures below and inspect the listed source sites.

## Check Procedure
1. Search the latest log for `fallback`, `unresolved return type`, `draw_eval_object`, `draw_ufunc_object`, and `Skipping unsupported aggregate`.
2. If the symptom matches an entry below, inspect that code path before opening a new frontier.
3. When a fallback is removed or narrowed, update this file in the same change.

## sv-tests Vacuous-PASS Audit (2026-05-11 — Phase 84)

Net result after P74–P84: **1027 PASS / 0 WARN-PASS / 0 FAIL / 0 TIMEOUT / 0 ERROR** out of 1027.  All documented vacuous-PASS rows closed via real iverilog implementations.

The harness (`sv-tests/run_iverilog.py`) now classifies vacuous PASSes as `WARN-PASS` via three rules:
1.  Stderr matches `_VACUOUS_STDERR_PAT` (`compile-progress[: ]`, `vvp.tgt sorry:`, `tgt-vvp sorry:`, `: sorry: SEQ_*`, `: sorry: ... not yet migrated`) AND is not equivalence-preserving (`compile-progress: treated as blocking`/`as wire`).
2.  Source contains a *success-side* `:assert:` (not in an `else`-clause failure action, not in a format-specifier template, not statically falsy) AND sim output has no `:assert:` line.
3.  Otherwise PASS.

**0 remaining WARN-PASS** — all 6 SVA composite-operator rows closed in Phase 84 by extending `pform_sva_seq.cc::synth_concat_` to recurse on composite kids and `synth_or_` to accept different length ranges.

Across the full sv-tests sweep, only **9 source files (1027 total)** emitted any `compile-progress` / `sorry:` warning.  The other six were tests whose warning is benign:
- 2 testbench files (`uvm_agent_active.sv`, `uvm_driver_sequencer_env.sv`) — `non-blocking assignment in function (compile-progress: treated as blocking)`.  Filtered by `_BENIGN_PROGRESS_PAT`; equivalence-preserving in zero-time function context.
- 1 preprocessing test (`22.5.1--define-expansion_26`) — `compile-progress: unresolved reference for clock_master` (test-source artefact, not iverilog gap).

**Closed rows from earlier audits (no longer vacuous):**

| Test (formerly WARN-PASS) | Closed by |
|---|---|
| `chapter-15/15.5.1--named-event-trigger-blocking.sv` | P75 `->>` real impl |
| `chapter-15/15.5.1--named-event-trigger-non-blocking.sv` | P75 `->>` real impl |
| `chapter-9/9.4.2.4--event_sequence.sv` | P78 `@<sequence>` procedural wait |
| `chapter-9/9.7--process_cls_suspend_resume.sv` | P77 `process::suspend/resume` opcodes |
| `chapter-18` 51 tests (UVM library `find_unused_resources` `Could not find variable 'a'`) | P79 `symbol_search` class-no-shadow-local-var |
| `chapter-18/18.9--controlling-constraints-with-constraint_mode_*` | P76 `constraint_mode` setter+getter |
| `chapter-18/18.5.8.{1,2}` (array reduction + foreach constraints) | P81 array `.sum()` + foreach + Z3 extract + wide writeback |
| 24 chapter-16 SVA tests with `else`-clause `:assert:` | P80 refined harness rule (false WARN-PASS) |
| 2 testbench tests with `treated as blocking` | P80 benign-progress filter (false WARN-PASS) |
| 6 chapter-16 SVA composite-operator tests (`SEQ_CONCAT` composite operands + `SEQ_OR` mixed lengths) | P84 — composite-operand recursion + length-range union in `pform_sva_seq.cc` |

## Active Fallbacks And Workarounds
- UVM phase startup/runtime frontier
  Source: `iverilog/vvp/vthread.cc` (`%fork/v`, `do_join`, non-local join-jump handling), exercised through `uvm_pkg::uvm_root.run_test` and `uvm_pkg::uvm_phase_hopper.run_phases`
  Symptom: reduced/full UVM startup now compiles and runs far enough to execute user `build_phase` and `run_phase`, but the reduced repro still hangs after `phase.drop_objection(this)` instead of finishing cleanly.
  Focused repro: `uvm_testbench/uvm_phase_progress_repro.sv`
  Supporting repro: `uvm_testbench/uvm_run_phases_build_probe.sv`
  Supporting probe: `uvm_testbench/uvm_run_test_counters_probe.sv` now proves `CTR_TEST_NEW count=1 name=uvm_test_top`.
  Supporting proof: current `uvm_phase_progress_repro.sv` run now reaches `TEST_BUILD`, `WORKER_BUILD`, `TEST_RUN_ENTER`, `WORKER_RUN_ENTER`, and `TEST_RUN_DROP`.
  Supporting reduction: `uvm_testbench/uvm_phase_hopper_worker_loop_probe.sv` strips away `wait_for_objection()` and now reaches `WLP_PROCESS_ENTER`, so the old “worker loop never starts” theory remains closed.
  Supporting proof: `uvm_testbench/uvm_hopper_two_gets_probe.sv` confirms the hopper queue still returns `build` then `common`, so the active issue is not phase enqueue/dequeue order.
  Supporting probe: `uvm_testbench/uvm_direct_wait_probe.sv` now passes, so direct `uvm_phase.wait_for_state()` wakeups are no longer the primary blocker.
  Supporting proof: the reduced run still emits `UVM/DPI/REGEX` errors plus automatic-context repair warnings such as `recv-object-aa`, `uvm_hdl_concat2string`, and `uvm_wait_for_nba_region`, so the remaining runtime frontier is now later than pre-build startup.
  Detached-frame retention status (Phase 63b/B9, 2026-05-02): the
  `vthread_get_rd_context_item_scoped could not find a live automatic
  context` symptom for `fork ... join_none` in a class task no longer
  reproduces with three reduced shapes (autotask capture; bare parent-
  local read; nested chained autotask frames).  Phase 59 commit
  2d4432afb pinned the autotask self frame in `owned_context` on fork
  and resolved this slice.  Regression coverage:
  `iverilog/tests/b9_detached_fork_context_test.sv` (all three shapes).
  Related reduced regression:
  `iverilog/ivtest/ivltests/sv_class_auto_recursive_raise1.v`.

- Expression-method compile-progress stubs
  Source: `iverilog/elab_expr.cc:2020`, `iverilog/elab_expr.cc:2277`, `iverilog/elab_expr.cc:4635`, `iverilog/elab_expr.cc:5512`
  Symptom: missing methods/functions silently become typed placeholders such as `null`, `0`, empty string, or queue-like stand-ins.

- Task compile-progress stubs
  Source: `iverilog/elaborate.cc:4789`, `iverilog/elaborate.cc:5212`
  Symptom: selected unresolved UVM task calls are ignored so compilation can continue.

- Unresolved functor stubs
  Source: `iverilog/vvp/compile.cc:762`
  Symptom: warnings such as `unresolved functor stub: ...; created placeholder net` appear at startup, especially in reduced/full UVM phase smokes.

- Object-context null fallbacks
  Source: `iverilog/tgt-vvp/eval_object.c:649`, `iverilog/tgt-vvp/eval_object.c:762`, `iverilog/tgt-vvp/eval_object.c:768`, `iverilog/tgt-vvp/draw_ufunc.c:350`
  Symptom: warnings such as `eval_object_sfunc: unsupported sfunc`, `draw_eval_object: unhandled/unknown expression type`, or `draw_ufunc_object: function ... returns non-object type ...; using null fallback`.

## Recently Cleared
- Static associative-array selected element method calls no longer drop to the indexed-object-method compile-progress stub.
  Fix: `iverilog/elaborate.cc`, `iverilog/elab_expr.cc`
  Regression: `iverilog/ivtest/ivltests/sv_class_static_assoc_method1.v`

- Detached `fork...join_none` task calls inside functions are now accepted during elaboration instead of being rejected as illegal task enables from a function body.
  Fix: `iverilog/elaborate.cc`
  Regression: `iverilog/ivtest/ivltests/sv_class_function_fork_task1.v`

- `uvm_domain.new` no longer loses its dynamic receiver state while running `uvm_phase.new` recursion for `m_end_node`, so the reduced constructor probe now reports the expected domain phase type and non-null end node.
  Fix: `iverilog/vvp/vthread.cc`, `iverilog/vvp/vvp_net_sig.cc`
  Regressions: `iverilog/ivtest/ivltests/sv_class_derived_ctor_state1.v`, `iverilog/ivtest/ivltests/sv_class_recursive_ctor_add1.v`
  Probe: `uvm_testbench/uvm_domain_ctor_probe.sv` now reports `DTYPE=4 ENDNULL=0`

- String equality/inequality against `""` now stays on the string-comparison path instead of collapsing to 1-bit `%cast/vec4/str` truthiness.
  Fix: `iverilog/elab_expr.cc`, `iverilog/tgt-vvp/eval_vec4.c`
  Regression: `iverilog/ivtest/ivltests/sv_string_cmp_empty1.v`

- Static class queue waits now wake after in-place queue mutation, and duplicate class-subtree target emission no longer splits wait-event cookies from the emitted queue storage.
  Fix: `iverilog/t-dll.cc`, `iverilog/t-dll.h`, `iverilog/t-dll-proc.cc`
  Regression: `iverilog/ivtest/ivltests/sv_class_static_queue_wait_wakeup1.v`

- Forward-declared class type parameters passed through parameterized helper classes no longer degrade to `logic[31:0]`, so `uvm_callback_iter#(..., uvm_reg_cbs)` and `uvm_callbacks#(..., uvm_reg_cbs)` now emit object-returning methods instead of `vec4` fallbacks.
  Fix: `iverilog/net_design.cc`
  Regression: `iverilog/ivtest/ivltests/sv_class_forward_typeparam_cb1.v`

- `uvm_phase.wait_for_state()` and equivalent case-wrapped class-property waits now subscribe to the active automatic formals instead of stale duplicate signals on the event nexus, so direct UVM phase waits wake after `set_state()`.
  Fix: `iverilog/tgt-vvp/vvp_scope.c`
  Regression: `iverilog/ivtest/ivltests/sv_class_case_wait_wakeup1.v`
  Probe: `uvm_testbench/uvm_direct_wait_probe.sv`

- The reduced caller-state regression behind the older `m_raise`/`m_propagate` context-loss path now runs cleanly on the current tree.
  Fix: `iverilog/vvp/vthread.cc`
  Regression: `iverilog/ivtest/ivltests/sv_class_auto_recursive_state1.v`

- Recursive same-scope automatic call setup no longer reads caller arguments from the freshly allocated callee frame, so class-property object-key AA `find()` recursion keeps live `succ`/`phase`/`orig` handles through nested calls.
  Fix: `iverilog/vvp/vthread.cc`
  Regression: `iverilog/ivtest/ivltests/sv_class_assoc_recursive_find1.v`

- Nested `break`/`continue` in automatic function loop-body child threads no longer return `0` by skipping the post-loop function code.
  Fix: `iverilog/tgt-vvp/vvp_proc_loops.c`, `iverilog/vvp/vthread.cc`, `iverilog/vvp/compile.cc`, `iverilog/vvp/codes.h`
  Regressions: `iverilog/ivtest/ivltests/sv_callf_nonlocal_break1.v`, `iverilog/ivtest/ivltests/sv_callf_nonlocal_continue1.v`

- Scoped class/static member alias paths now have a runtime smoke that checks actual static-member semantics instead of expecting per-instance storage for a class static.
  Fix: `uvm_testbench/sv_scoped_class_static_member_smoke.sv`
  Regression: `iverilog/ivtest/ivltests/sv_scoped_class_static_member1.v`

- Module-scope variables of nested class types now resolve the enclosing class name as a real type identifier, so handles like `waiter_t w;` no longer fall into module-instantiation parsing and class event-member smoke cases compile and run.
  Fix: `iverilog/pform.cc`
  Regression: `iverilog/ivtest/ivltests/sv_class_event_member1.v`

- Class-property object-key associative-array `foreach` and `find()` no longer double-unwrap the index type to `int`, so phase/object lookups iterate with object-key AA traversal instead of scalar-key opcodes.
  Fix: `iverilog/elab_type.cc`
  Regression: `iverilog/ivtest/ivltests/sv_class_prop_assoc_find1.v`

- Top-level object-key associative-array signal stores and iteration now use direct signal-backed AA opcodes for scalar/object values, so nil signal receivers no longer drop the first store before `foreach`.
  Fix: `iverilog/tgt-vvp/stmt_assign.c`, `iverilog/vvp/compile.cc`, `iverilog/vvp/codes.h`, `iverilog/vvp/vthread.cc`
  Regression: `iverilog/ivtest/ivltests/sv_assoc_typedef_foreach_key1.v`

- Assoc-compat arrays of queues now materialize missing selected queue receivers into the associative array itself, then reload the stored instance before mutating it, so nested `foreach` and element access no longer operate on detached temporaries.
  Fix: `iverilog/elaborate.cc`, `iverilog/elab_expr.cc`, `iverilog/tgt-vvp/vvp_process.c`, `iverilog/vvp/vvp_darray.cc`
  Regressions: `iverilog/ivtest/ivltests/sv_assoc_queue_foreach1.v`, `iverilog/ivtest/ivltests/sv_assoc_queue_class_select1.v`

- Nested object selects whose base is already a queue/darray select no longer fall into `eval_object_select: base is not a signal (type 7)` null fallbacks.
  Fix: `iverilog/tgt-vvp/eval_object.c`
  Regression: `iverilog/ivtest/ivltests/sv_assoc_queue_class_select1.v`

- Temporary-expression member access no longer parses to `null`.
  Fix: `iverilog/parse.y`, `iverilog/elab_expr.cc`
  Regression: `iverilog/ivtest/ivltests/sv_class_call_result_prop1.v`

- Queue-property `[$]` no longer loses the receiver while synthesizing `size()-1`.
  Fix: `iverilog/elab_expr.cc`, `iverilog/tgt-vvp/vvp_priv.h`, `iverilog/tgt-vvp/eval_object.c`, `iverilog/tgt-vvp/eval_real.c`, `iverilog/tgt-vvp/eval_string.c`, `iverilog/tgt-vvp/eval_vec4.c`
  Regression: `iverilog/ivtest/ivltests/sv_class_queue_last_prop1.v`

- Class property associative-array struct literal stores no longer collapse to `null`/number fallbacks.
  Fix: `iverilog/elab_expr.cc`, `iverilog/net_assign.cc`, `iverilog/net_expr.cc`, `iverilog/elab_lval.cc`, `iverilog/tgt-vvp/draw_class.c`, `iverilog/vvp/class_type.cc`
  Regression: `iverilog/ivtest/ivltests/sv_class_prop_assoc_struct_lit1.v`

- Local unpacked-struct cobject variables now materialize real struct instances, and member stores no longer collapse to offset-0/null behavior.
  Fix: `iverilog/elab_lval.cc`, `iverilog/tgt-vvp/vvp_scope.c`, `iverilog/tgt-vvp/draw_class.c`, `iverilog/vvp/parse.y`, `iverilog/vvp/words.cc`, `iverilog/vvp/vvp_net_sig.cc`
  Regression: `iverilog/ivtest/ivltests/sv_unpacked_struct_local_member_assign1.v`

- Queue element packed-member slices now elaborate and run through queue `push_back` without dropping the selected value.
  Fix: `iverilog/elab_expr.cc`, `iverilog/elaborate.cc`, `iverilog/elab_lval.cc`, `iverilog/tgt-vvp/vvp_scope.c`, `iverilog/vvp/vvp_net_sig.cc`
  Regression: `iverilog/ivtest/ivltests/sv_queue_struct_member_slice_push1.v`

- Queue element class-member l-values no longer assert in `elab_lval`.
  Fix: `iverilog/elab_lval.cc`
  Regression: `iverilog/ivtest/ivltests/sv_queue_class_member_lval1.v`

- Benign read-context resync during `_ivl_4.__deferred_init` no longer emits a UVM startup warning when only the read side is scope-filtered.
  Fix: `iverilog/vvp/vthread.cc`
  Regression coverage: exercised by the UVM smoke run and object/context regressions such as `iverilog/ivtest/ivltests/sv_class_recursive_new_prop1.v`

- Local unpacked-array-of-struct assignment patterns now run correctly for the focused struct/string case and no longer need compile-only coverage.
  Fix: `iverilog/tgt-vvp/stmt_assign.c`, `iverilog/tgt-vvp/eval_object.c`
  Regression: `iverilog/ivtest/ivltests/sv_uarray_struct_pattern1.v`

- Object-key associative-array lookups used in ternaries with `null` now keep class typing through runtime, not just compilation.
  Fix: `iverilog/net_expr.cc`, `iverilog/netlist.h`
  Regression: `iverilog/ivtest/ivltests/sv_class_assoc_ternary_null1.v`

- Struct aggregate actuals with string members now pass through task/function formals as whole cobjects instead of falling into `%store/obja` null fallbacks.
  Fix: `iverilog/tgt-vvp/stmt_assign.c`
  Regression: `iverilog/ivtest/ivltests/sv_struct_string_arg_push1.v`

- Aggregate function formals backed by real aggregate property metadata no longer hit `Skipping unsupported aggregate function argument/send ...`.
  Fix: `iverilog/tgt-vvp/draw_ufunc.c`
  Regression coverage: exercised by the UVM smoke compile path through `uvm_factory.svh`

- Unpacked-struct returns from specialized `uvm_queue` methods no longer emit false unresolved-return debug lines during elaboration/export.
  Fix: `iverilog/elab_sig.cc`, `iverilog/t-dll.cc`
  Regression coverage: exercised by the UVM smoke compile path through `uvm_queue.svh`

- Selected-target `foreach` now elaborates through real identifier/member-path resolution instead of rejecting package statics and nested object chains.
  Fix: `iverilog/elaborate.cc`, `iverilog/elab_type.cc`, `iverilog/elab_sig.cc`, `iverilog/pform.cc`, `iverilog/Statement.cc`
  Regressions: `iverilog/ivtest/ivltests/sv_assoc_obj_graph_mutation1.v`, `iverilog/ivtest/ivltests/sv_assoc_nested_member_foreach1.v`, `iverilog/ivtest/ivltests/sv_assoc_static_class_foreach1.v`
