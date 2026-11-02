# Diagnostic trace environment variables

`ivl` (the compiler), `tgt-vvp` and `vvp` (the runtime) read a number of
`IVL_*` environment variables that switch on developer traces. A trace
only adds diagnostic output (one exception is noted in its row). All of them
print to standard error, except
`IVL_UVM_REGEX_TRACE`, which goes through `vpi_printf` (standard output and
the log file), so leave it unset when comparing simulation logs.

This page lists the traces that were not documented anywhere else
(inventory at `a972e2d57`, 2026-11-01). Variables that change behavior,
such as `IVL_SVA_NFA`, `IVL_SAME_TIME_LIMIT` and `IVL_TRAMPOLINE_CALLF`,
are not traces; see [CHANGES](../CHANGES.md) and the design notes linked
from the [documentation index](README.md).

## Value forms

| Form | Meaning |
| --- | --- |
| on | Non-empty and not `0`. |
| any | Any value, including empty or `0`; only unset turns it off. |
| filter | Non-empty. `1`, `ALL` or `*` (some also `true`) selects everything; any other value is a substring matched against the named scope, class or callee. |
| N | A positive decimal count. |

## Compiler (`ivl`)

| Variable | Value | Prints | Source |
| --- | --- | --- | --- |
| `IVL_CLASS_METHOD_TRACE` | on (the scope and method-miss sites accept any non-empty value) | Class-method resolution: `trace scoped-func class-step`, `trace scoped-func method`, `trace task-method`; `trace class-scope` and `trace specialized-class-scope` only for `uvm_reg_frontdoor`; `trace method-miss` only for `start`, `atomic_lock` and `atomic_unlock` | `elab_expr.cc`, `elab_scope.cc`, `elaborate.cc`, `netclass.cc` |
| `IVL_CONST_TRACE` | filter (`1` or `all`; else caller or callee path substring) | `const-trace:` lines when a constant-function call is elaborated or materialized | `elab_expr.cc`, `net_design.cc` |
| `IVL_COV_TRACE` | any | `[cov-source-trace]` coverpoint source types and `[cov-trace]` cross bin products | `elaborate.cc` |
| `IVL_CTOR_BLEND_TRACE` | on | Constructor scope dumps, only for `uvm_default_report_server::new` | `elaborate.cc` |
| `IVL_EXPR_CONST_TRACE` | on | `trace expr_const:` value, width and signedness of each constant handed to the target | `t-dll-expr.cc` |
| `IVL_FIND_TRACE` | any | `[find-trace]` receiver, path and dispatch decisions for array-locator and method calls | `elab_expr.cc` |
| `IVL_FOREACH_TYPE_TRACE` | non-empty (even `0`; an empty value prints only the `[resolve-placeholder]` lines) | `[resolve-placeholder]` and `foreach-type:` index-type resolution | `elab_sig.cc`, `elab_type.cc` |
| `IVL_FUNC_SIG_TRACE` | substring of the function's scope path | `trace func-sig` enter and exit for matching function signatures | `elab_sig.cc` |
| `IVL_LOCAL_CLASS_WAIT_TRACE` | on | `trace local-class-nex-input` pre and post sensitivity sets | `net_nex_input.cc` |
| `IVL_NESTED_PATH_TRACE` | any | `debug:` reason a nested class-property path or l-value tail was rejected; `debug: elaborate_sig` property types for the UVM properties `m_time_settings`, `m_verbosity_settings`, `m_regs_info` and `m_mems_info` | `elab_expr.cc`, `elab_lval.cc`, `elab_sig.cc` |
| `IVL_NETECONST_TRACE` | any | `trace neteconst` constructor and `cast_signed` before/after values | `netlist.cc` |
| `IVL_NUM_ELAB_TRACE` | on | `trace penumber typed` and `trace penumber width` raw and cast values of typed and sized numbers | `elab_expr.cc` |
| `IVL_PROP_WAIT_TRACE` | on | `trace prop-nex-input` pre and post sensitivity sets for class properties | `net_nex_input.cc` |
| `IVL_STATIC_TYPECALL_TRACE` | on | `static-typecall` resolution of static class calls | `elab_expr.cc` |
| `IVL_SVA_NFA_DUMP` | on | Assertion NFAs (antecedent, fan-out, consequence obligation) as they are built | `pform_sva_nfa.cc`, `pform.cc` |
| `IVL_UVM_CB_SIG_TRACE` | any | `trace: uvm_cb_sig` method signatures in `uvm_callbacks` and `uvm_typed_callbacks`. It reads the class's `CB` and `T` parameters while printing, which may evaluate them earlier than an untraced run | `elab_sig.cc` |
| `IVL_UVM_CB_SPEC_TRACE` | any | `trace: uvm_cb_spec` specialization of the UVM callback classes | `elab_scope.cc` |

## Code generator (`tgt-vvp`)

| Variable | Value | Prints | Source |
| --- | --- | --- | --- |
| `IVL_EVENT_INPUT_TRACE` | on | `trace event-input` nexus pointers feeding each event | `tgt-vvp/vvp_scope.c` |
| `IVL_QRECV_TRACE` | any | `[qrecv]` queue-receiver argument types | `tgt-vvp/vvp_process.c` |
| `IVL_VVP_NUM_TRACE` | on | `trace num:` for each vec4 constant; `trace vec4:` for every expression lowered to vec4 | `tgt-vvp/eval_vec4.c` |

## Runtime (`vvp` and its modules)

| Variable | Value | Prints | Source |
| --- | --- | --- | --- |
| `IVL_ASSOC_TRACE` | filter (thread scope) | `trace assoc:` associative-array operations | `vvp/vthread.cc` |
| `IVL_CALLF_DUMP_TREE` | filter (caller or callee; `true` also selects all) | The thread tree under a function call when the caller blocks on it. Only with `IVL_TRAMPOLINE_CALLF=0` | `vvp/vthread.cc` |
| `IVL_CALLF_TRACE` | on | `trace callf-wait:` function calls that block. Only with `IVL_TRAMPOLINE_CALLF=0` | `vvp/vthread.cc` |
| `IVL_CALLF_TRACE_TARGET` | `ALL` or `*` select all; `1` or `true` select a small default set of call sites; `0` is off; else caller or callee substring | `trace callf[n]` function-call entries; `trace callf-post[n]` (callee only, only with `IVL_TRAMPOLINE_CALLF=0`) | `vvp/vthread.cc` |
| `IVL_CALLF_TRACE_LIMIT` | N | Caps the `IVL_CALLF_TRACE_TARGET` lines | `vvp/vthread.cc` |
| `IVL_CAST_TRACE` | on | `trace $cast:` argument types and result | `vpi/sys_sv_class.cc` |
| `IVL_CLASS_TRACE` | filter (class name; `true` also selects all) | `trace class:` property get and set calls | `vvp/class_type.cc` |
| `IVL_EVENT_TRACE` | on | `trace anyedge-*` event receive calls | `vvp/event.cc` |
| `IVL_FUNC_TRACE_LIMIT` | N | Caps the `trace func-schedule` and `trace func-pause` lines of `IVL_FUNC_TRACE` | `vvp/vthread.cc` |
| `IVL_LOAD_VEC_TRACE` | filter (scope) | `trace load-vec4-aa` automatic-variable vector loads | `vvp/vvp_net_sig.cc` |
| `IVL_PC_HOTTRACE_LIMIT` | N (default 100000) | Hit count after which `IVL_PC_HOTTRACE` reports an instruction as a hotspot | `vvp/vthread.cc` |
| `IVL_PC_PROGRESS_LIMIT` | N (default 1000000) | Executed instructions between `IVL_PC_PROGRESS` reports | `vvp/vthread.cc` |
| `IVL_PROP_TRACE` | filter (thread scope) | `trace prop:` class-property loads and stores | `vvp/vthread.cc` |
| `IVL_RECV_OBJ_TRACE` | filter (scope) | `trace recv-object-aa` automatic-variable object receives | `vvp/vvp_net_sig.cc` |
| `IVL_RECV_VEC_TRACE` | filter (scope) | `trace recv-vec4-aa` automatic-variable vector receives | `vvp/vvp_net_sig.cc` |
| `IVL_SEQ_TRACE` | non-empty (even `0`) | `[SEQ_TRACE anyedge recv_object]` sequence-event wakeups | `vvp/event.cc` |
| `IVL_STEP_TRACE_LIMIT` | N (default 256) | Caps the `trace step[n]` lines of `IVL_STEP_TRACE` | `vvp/vthread.cc` |
| `IVL_STORE_OBJ_TRACE` | filter (thread scope) | `trace load_obj` and `trace store_obj` object loads and stores | `vvp/vthread.cc` |
| `IVL_STORE_STR_TRACE` | filter (thread scope) | `trace store_str-pre`, `-ctx` and `-post` string stores | `vvp/vthread.cc` |
| `IVL_UVM_REGEX_TRACE` | any | `trace UVM regex:` each pattern compiled by the UVM DPI (via `vpi_printf`) | `uvm_dpi/uvm_dpi_iverilog.cc` |
| `IVL_VPI_CALL_TRACE` | on | System task and function calls made through VPI | `vvp/vthread.cc` |
| `IVL_VPI_CALL_TRACE_TARGET` | substring of thread scope, task name or call scope | Narrows `IVL_VPI_CALL_TRACE` | `vvp/vthread.cc` |
