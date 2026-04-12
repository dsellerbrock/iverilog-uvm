# SystemVerilog/UVM Enablement Fixes

This branch carries a broad SystemVerilog and UVM compatibility pass across
frontend elaboration, the `tgt-vvp` backend, and the `vvp` runtime. The work is
not a single feature; it is a stack of interlocking fixes needed to move modern
class-heavy UVM code from compile-progress fallbacks toward real execution.

## Scope

The main change areas are:

- frontend parsing and elaboration in `elab_*.cc`, `elaborate.cc`,
  `net_design.cc`, `net_scope.cc`, `netclass.cc`, `parse.y`,
  `pform*.{h,cc}`
- VVP lowering in `tgt-vvp/*.c`
- VVP runtime and VPI support in `vvp/*.cc`, `vvp/*.h`, and `vpi/*.cc`
- focused regression coverage in `ivtest/ivltests/`

## Major Fix Categories

### 1. Parameterized class and type binding

- fixed forward-declared class type-parameter recovery so parameterized callback
  and registry paths preserve object types instead of degrading to
  `logic[31:0]`
- tightened specialized-class cache key construction and lookup caching to
  reduce duplicate specializations and stale symbol/type reuse
- fixed null/class typing so ternaries like `cond ? aa[key] : null` stay class
  typed through elaboration and runtime

Representative files:

- `net_design.cc`
- `elab_scope.cc`
- `net_scope.cc`
- `netclass.cc`
- `netlist.h`

Representative tests:

- `sv_class_forward_typeparam_cb1.v`
- `sv_class_assoc_ternary_null1.v`

### 2. Class property, queue, darray, and associative-array lowering

- added indexed queue-property read/write lowering for vec4, object, real, and
  string paths
- fixed nested member and selected-container elaboration such as
  `obj.q[i].field`, `obj.arr[i].method()`, and queue element member l-values
- repaired object-key and selected associative-array paths used by UVM callback,
  phase, and resource logic
- fixed queue `[$]`, `insert`, `delete`, and object/aggregate element store
  handling

Representative files:

- `elab_expr.cc`
- `elab_lval.cc`
- `elab_type.cc`
- `elaborate.cc`
- `tgt-vvp/eval_object.c`
- `tgt-vvp/eval_vec4.c`
- `tgt-vvp/stmt_assign.c`
- `tgt-vvp/vvp_process.c`

Representative tests:

- `sv_queue_class_member_lval1.v`
- `sv_class_queue_insert_wait_wakeup1.v`
- `sv_class_prop_assoc_struct_lit1.v`
- `sv_assoc_queue_class_select1.v`
- `sv_assoc_typedef_foreach_key1.v`

### 3. Virtual dispatch, casts, and object/VPI plumbing

- extended virtual dispatch across inheritance chains instead of requiring an
  exact leaf override match
- fixed override argument handoff for named scope items
- fixed function-form class `$cast(dest, src)` for both direct class variables
  and function return variables
- added declared-class metadata to VPI-backed class handles and typed object
  stack handles so runtime type checks stop collapsing to generic vectors

Representative files:

- `tgt-vvp/draw_vpi.c`
- `t-dll.cc`
- `t-dll-proc.cc`
- `t-dll.h`
- `vvp/class_type.{cc,h}`
- `vvp/vpi_cobject.cc`
- `vvp/vpi_vthr_vector.cc`
- `vpi/sys_sv_class.cc`

Representative tests:

- `sv_virtual_inherit_dispatch1.v`
- `sv_virtual_prop_return_dispatch1.v`
- `sv_virtual_task_output_copy1.v`
- `sv_class_cast_runtime1.v`
- `sv_class_cast_return1.v`

### 4. Automatic-context, fork/join, and callf/runtime semantics

- stabilized automatic-context ownership for recursive calls, detached children,
  and class task/function flow-control paths
- fixed same-scope recursive argument capture and constructor receiver/state
  corruption
- improved synchronous `callf` draining, `%join` wakeup behavior, and detached
  named-scope context binding
- removed several false-positive context repair paths while preserving targeted
  diagnostics for real runtime corruption

Representative files:

- `vvp/vthread.cc`
- `vvp/vthread.h`
- `vvp/vpi_scope.cc`
- `vvp/vvp_net_sig.{cc,h}`
- `vvp/event.{cc,h}`
- `vvp/schedule.cc`

Representative tests:

- `sv_callf_nonlocal_break1.v`
- `sv_callf_nonlocal_continue1.v`
- `sv_class_auto_recursive_state1.v`
- `sv_class_auto_recursive_raise1.v`
- `sv_class_recursive_ctor_add1.v`
- `sv_class_derived_ctor_state1.v`

### 5. Object mutation wakeups and wait/event correctness

- added object mutation tracking so in-place class/queue updates can wake waiters
- fixed implicit wait-event input selection to bind to the active automatic
  signal instead of stale duplicate nexus entries
- deduplicated target-layer class subtree emission so queue wait cookies and
  queue storage land on the same emitted signal tree
- fixed string compare lowering so `string == ""` and `string != ""` stay on
  the string compare path

Representative files:

- `vvp/vvp_object.{cc,h}`
- `vvp/vvp_darray.{cc,h}`
- `vvp/vvp_net_sig.cc`
- `tgt-vvp/vvp_scope.c`
- `t-dll.cc`
- `elab_expr.cc`
- `tgt-vvp/eval_vec4.c`

Representative tests:

- `sv_class_prop_wait_wakeup1.v`
- `sv_class_method_prop_wait_wakeup1.v`
- `sv_class_static_queue_wait_wakeup1.v`
- `sv_class_case_wait_wakeup1.v`
- `sv_string_cmp_empty1.v`

## Regression Coverage Added

This branch adds a large focused regression set under `ivtest/ivltests/`. The
most important new coverage areas are:

- callback/type-parameter recovery
- virtual dispatch and cast/runtime behavior
- recursive constructor and automatic call state
- class property waits and queue wakeups
- associative-array object-key recursion and copy isolation
- queue/container member l-values and struct/object aggregate paths

See `ivtest/regress-sv.list` for the full list registered by this branch.

## Current Known Incomplete Areas

This tree is materially closer to UVM support, but it is not finished. Active
work remains around:

- UVM phase startup/runtime flow in `uvm_root.run_test` /
  `uvm_phase_hopper.run_phases`
- a small set of compile-progress stubs still used for unresolved methods/tasks
- unresolved functor placeholder warnings in reduced/full UVM runs
- remaining object-context fallback paths in `tgt-vvp`

## Supporting Workspace Logs

The workspace wrapper also carries investigation logs that are not part of the
git repo:

- `../FALLBACKS.md`
- `../UVM_PHASE_STARTUP_LOG.md`

Those files record active frontiers, reduced repros, and recently cleared
issues in more detail than this summary.
