# SystemVerilog/UVM Enablement — Technical Design Document

This document describes every change in the `development` branch relative to
`steveicarus/iverilog` `master`. Changes are grouped by feature area. For each
feature: what was broken, the root cause, the fix, files changed, and test coverage.

**Branch:** `dsellerbrock/iverilog-uvm` `development`
**Base:** `steveicarus/iverilog` `master` (86 commits ahead)
**Upstream status** is noted for each group — see §11 for the summary table.

---

## Table of Contents

1. [Core SV Class and OOP Infrastructure](#1-core-sv-class-and-oop-infrastructure)
2. [Automatic Context, Fork/Join, and Thread Semantics](#2-automatic-context-forkjoin-and-thread-semantics)
3. [Constrained Randomization](#3-constrained-randomization)
4. [Virtual Interfaces as Class Members](#4-virtual-interfaces-as-class-members)
5. [UVM Register Layer](#5-uvm-register-layer)
6. [Functional Coverage](#6-functional-coverage)
7. [DPI-C Import](#7-dpi-c-import)
8. [String Methods, Class Arrays, Assoc Array Fixes](#8-string-methods-class-arrays-assoc-array-fixes)
9. [Grammar Fixes (parse.y)](#9-grammar-fixes-parsey)
10. [CI / Build Portability](#10-ci--build-portability)
11. [Upstream Readiness Summary](#11-upstream-readiness-summary)
12. [Known Limitations and Deferred Work](#12-known-limitations-and-deferred-work)
13. [Commit Index](#13-commit-index)

---

## 1. Core SV Class and OOP Infrastructure

**Commits:** `5b45ab3`, `982b56f`, `6214779`, `6f9373e`, `c82e37e`, `5f2bbb9`,
`2ae0d1d`, `95a9b32`, `3349f35`, `80877c2`, `96ff395`, `2ca7d41`, `da31167`

These are the foundational commits that make iverilog capable of compiling and running
class-based SV code. They constitute the largest body of change and cover many
orthogonal features.

---

### 1.1 Nested Function Flow Control (`break`/`continue` in callf)

**Commit:** `5b45ab3` — *Fix nested function loop flow control*

**Problem:** `break` and `continue` inside a loop in an automatic function called from
another loop (`callf` context) would propagate the flow-control signal past the function
boundary, breaking the outer loop or causing incorrect termination.

**Root cause:** The `vvp` runtime's `%callf` opcode did not save/restore the
`flow_control` register when entering/exiting a called function. Non-local flow control
(break, continue, return) was represented as a flag in the thread that any enclosing
loop would check, but the flag was not cleared when entering a nested call frame.

**Fix:** `vvp/vthread.cc` — save and restore the flow control state on `%callf` entry
and exit so that `break`/`continue` inside a called function's loop cannot escape the
function boundary. Also corrects `vvp/codes.h` and `vvp/compile.cc` for new opcode
variants, and `tgt-vvp/vvp_proc_loops.c` for correct emission.

**Tests added:** `ivtest/ivltests/sv_callf_nonlocal_break1.v`,
`sv_callf_nonlocal_continue1.v`

---

### 1.2 Broad SV Class Support

**Commits:** `982b56f`, `6214779`, `6f9373e`

These three large commits bring iverilog from "parses some SV class syntax" to
"runs UVM-style object-oriented code." They cover:

#### Parameterized Classes and Type Binding

- Fixed forward-declared class type-parameter recovery: when a `class C #(type T=X)`
  is referenced before its full specialization is known, the type degrades to
  `logic[31:0]`. The fix tightens the specialization cache key so parameterized
  callback and registry paths preserve the correct object type.
- Fixed null/class typing: ternaries like `cond ? aa[key] : null` now stay class-typed
  through elaboration and into the runtime.

**Files:** `net_design.cc`, `elab_scope.cc`, `net_scope.cc`, `netclass.cc`, `netlist.h`

#### Class Property, Queue, Darray, and Assoc-Array Lowering

- Added indexed queue-property read/write lowering for all element types (vec4,
  object, real, string).
- Fixed nested member elaboration: `obj.q[i].field`, `obj.arr[i].method()`, and queue
  element member l-values.
- Repaired object-key and selected associative-array paths used by UVM callback, phase,
  and resource logic.
- Fixed queue `[$]`, `insert()`, `delete()`, and object/aggregate element store handling.

**Files:** `elab_expr.cc`, `elab_lval.cc`, `elab_type.cc`, `elaborate.cc`,
`tgt-vvp/eval_object.c`, `tgt-vvp/eval_vec4.c`, `tgt-vvp/stmt_assign.c`,
`tgt-vvp/vvp_process.c`

#### Virtual Dispatch, Casts, VPI Plumbing

- Extended virtual dispatch across full inheritance chains (not just one level).
- Fixed `$cast(dest, src)` for both direct class variables and function return values.
- Added declared-class metadata to VPI-backed class handles so runtime type checks stop
  collapsing to generic vectors.

**Files:** `tgt-vvp/draw_vpi.c`, `t-dll.cc`, `t-dll.h`, `vvp/class_type.{cc,h}`,
`vvp/vpi_cobject.cc`, `vpi/sys_sv_class.cc`

#### Object Mutation Wakeups

- Added object mutation tracking so in-place class/queue updates wake waiting threads.
- Fixed wait-event input selection to bind to the active automatic signal instead of
  a stale nexus.

**Files:** `vvp/vvp_object.{cc,h}`, `vvp/vvp_darray.{cc,h}`, `vvp/vvp_net_sig.cc`,
`tgt-vvp/vvp_scope.c`

#### New vvp Runtime Infrastructure

- `vvp/vvp_vinterface.{cc,h}` — new `vvp_vinterface` object type for virtual interface
  handles (used in Phases 3+)
- `vvp/vvp_assoc.{cc,h}` — associative array runtime implementation
- `vvp/words.cc` — VVP word-level helpers for object/class values

**Tests added (83 total in regress-sv.list):** Key examples:
`sv_class_forward_typeparam_cb1.v`, `sv_class_assoc_ternary_null1.v`,
`sv_virtual_inherit_dispatch1.v`, `sv_class_cast_runtime1.v`,
`sv_class_prop_wait_wakeup1.v`, `sv_class_queue_insert_wait_wakeup1.v`,
`sv_assoc_typedef_foreach_key1.v`, `sv_class_auto_recursive_state1.v`

---

### 1.3 UVM-Specific Elaboration Fixes

**Commits:** `c82e37e`, `95a9b32`, `3349f35`, `80877c2`, `96ff395`

#### Class Elaboration Ordering (`c82e37e`)

**Problem:** UVM uses complex class hierarchies where a parent class method calls a
method on a child class type that is not yet elaborated when the parent's scope is
processed.

**Fix:** `elaborate.cc` — defer method elaboration for forward-referenced class members
until all class scopes are known. Prevents "method not found in class" spurious errors
during UVM base class compilation.

#### Package-Scoped Function Call within Same Package (`95a9b32`)

**Problem:** `uvm_pkg::uvm_report()` calls within the same package body (e.g., the
string `join` helper) failed with "task/function not found" because the symbol search
started one scope too high, skipping the package scope.

**Fix:** `symbol_search.cc` — when searching for a task/function name from inside a
package body, include the current package scope in the search before ascending to the
design root.

#### Factory Registration for Specialized Classes (`3349f35`)

**Problem:** `uvm_component_registry#(T,...)::create_object_by_type()` failed at
runtime because no `$init` thread was generated for the specialized class. The factory
registration macro expands to a static field initialization that needs a thread to run
at time 0, but iverilog only generated `$init` threads for the base specialization.

**Fix:** `elab_scope.cc` — when a class has `initialize_static` members, generate
`$init` threads for each concrete specialization, not just the base definition.

#### Compilation Hang Fix (`80877c2`)

**Problem:** Elaborating deeply specialized UVM classes (e.g., the callback registry
chain) caused infinite recursion in `elab_scope.cc`.

**Fix:** Added a recursion guard (class-being-specialized set) and stabilized the
specialization cache key construction to prevent duplicate/circular specialization.

#### Mailbox and Basic Randomize Runtime (`96ff395`)

**Problem:** `mailbox`, `semaphore`, and `$ivl_class_method$randomize` were not
implemented in the VVP runtime.

**Fix:**
- `vvp/vvp_mailbox.cc` — new file implementing the SV mailbox runtime: `put`, `get`,
  `peek`, `try_put`, `try_get`, `try_peek`, `num`
- `vvp/vthread.cc` — `of_RANDOMIZE`: iterates all `rand` properties, calls the PRNG,
  writes randomized values back via the cobject property API
- Semaphore implementation using internal counter and wait queue

---

### 1.4 Callf Opcode Type Mismatch (`5f2bbb9`)

**Problem:** When an automatic function returns a type that differs from the expression
context (e.g., function returns `uvm_object`, expression expects `uvm_component`), the
`%callf` opcode was emitted with the expression's type rather than the function's
declared return type. This caused a stack width mismatch that corrupted the return
value.

**Root cause:** `tgt-vvp/draw_ufunc.c` derived the return-value width from the call
expression's elaborated type, which could be narrower than the function's actual return
type after class specialization.

**Fix:** Use the function scope's declared return type width when emitting `%callf`,
falling back to the expression type only when the scope type is unavailable.

**Files:** `tgt-vvp/draw_ufunc.c`

---

### 1.5 Unnamed Begin-End Block Scoping (`2ae0d1d`)

**Problem:** UVM macros like `` `uvm_warning ``, `` `uvm_error ``, and `` `uvm_info ``
expand to:

```systemverilog
begin
  uvm_object _local_report_object_ = get_report_object();
  // ...
end
```

The inline variable declaration (`uvm_object _local_report_object_ = ...`) is
a `statement_or_null` inside the block body, not a `block_item_decl`. When there are
304 such macros in `uvm_pkg.sv`, all 304 variables land in the enclosing function
scope because the unnamed block scope had been deleted early.

**Root cause:** `parse.y` had an optimization in the `K_begin label_opt` grammar rule:
when an unnamed `begin...end` block had no `block_item_decls`, it deleted the block
scope before parsing `statement_or_null_list_opt`. The optimization was correct for
Verilog but broke SV, where inline declarations in `statement_or_null` are legal.

**Fix:** Move the scope-deletion check to *after* all statements are parsed.
`pform_block_scope_is_empty()` is called once all statements have been processed;
only then is the scope deleted if no declarations were added. This way UVM macro
inline declarations correctly land in their own block scope.

**Also in this commit:**
- `K_fork` scope fix: for `fork`, *never* delete the scope (always keep it), so that
  task calls inside `fork`/`join_none` inside a function see the fork's scope layer
  (not the function scope) and are not incorrectly rejected as "task call in function."
  Fixes `uvm_objection::m_init_objections` and `uvm_heartbeat`.

**Files:** `parse.y`, `vvp/event.cc`

---

### 1.6 VPI and Unresolved Net Handling (`2ca7d41`, `da31167`)

- `vvp/compile.cc`: Fine-tuned unresolved net reference handling; references to nets
  that are resolved later in elaboration no longer cause spurious "unresolved reference"
  errors at runtime.
- `da31167`: Fixed two regression bugs introduced during the broad SV class work that
  broke VPI-based tests (array VPI iteration and `$sformat` with class handles).

---

## 2. Automatic Context, Fork/Join, and Thread Semantics

**Commits:** `289ef9b`, `8ca869b` (partial), `d9e9bfb` (partial)

---

### 2.1 Automatic Context Recovery Warnings Behind Env Var (`289ef9b`)

**Problem:** The automatic-context repair code in `vvp/vthread.cc`,
`vvp/vvp_net_sig.cc`, and `vvp/event.cc` emitted `Warning:` messages to stderr on
every context mismatch. These are benign — the recovery code correctly handles all
cases — but they flooded UVM simulation output and confused users.

**Fix:** Added `auto_ctx_warn_enabled()` (declared in `vthread.h`, defined in
`vthread.cc`) that checks `getenv("IVL_AUTO_CTX_WARN")`. All context-recovery and
mismatch warnings are gated behind this check. Developers can set
`IVL_AUTO_CTX_WARN=1` to re-enable the warnings when debugging context threading.

**Files:** `vvp/vthread.cc`, `vvp/vthread.h`, `vvp/vvp_net_sig.cc`, `vvp/event.cc`

---

### 2.2 Post-Join Copy-Out via `sanitize_thread_contexts_` (`d9e9bfb`)

**Problem:** UVM register layer `uvm_reg::read()` uses a task (`XreadX`) called via
fork/join. After the join, the output variable `value` (written by `XreadX`) read back
as `X` (unknown), so all register reads returned 0.

**Root cause:** `sanitize_thread_contexts_()` in `vvp/vthread.cc` was silently dropping
the child task's context from `rd_context` after `%join`.

**Mechanism:** After `%join` for XreadX inside the `read` task, `do_join()` moves
`xreadx_ctx` to the *head* of `read`'s `rd_context` so that the `%load`/`%store`
copy-out sequence can read back XreadX's output variables (`value`, `status`). The
first `%store/vec4` for a variable in `read`'s own scope triggered
`ensure_write_context_()` → `sanitize_thread_contexts_()`. The sanitizer replaced
`rd_context` with `read`'s own scope context, discarding `xreadx_ctx`. The subsequent
`%load/vec4` of XreadX's `value` variable found no context and returned X.

**Fix:** In `sanitize_thread_contexts_()`, treat the head of `rd_context`
symmetrically with `wt_context`: preserve it if `context_live_in_owner()` returns
true (live in any scope owner), not only when it matches the thread's own scope. A
live-in-owner context at the `rd` head is legitimately placed there by `do_join()` for
copy-out; `%free` cleans it up normally afterward.

**Files:** `vvp/vthread.cc`

---

### 2.3 uvm_config_db Virtual Interface Context Chain (`8ca869b`)

**Problem:** `uvm_config_db #(virtual T)::get()` is compiled as an automatic function
with an `inout` parameter. After `do_join` returns the child frame, `rd_context` is a
chain `[child_frame → caller_frame]`. The copy-out sequence first loaded `this`
(caller scope), which advanced `rd_context` past the child frame, then tried to load
the `value` output parameter (child scope), which could no longer be found.

**Fix:** Remove the `rd_context = use_context` side effect from
`vthread_get_rd_context_item_scoped()`. The lazy advancement was redundant (every call
already uses `first_live_context_for_scope` to walk the chain) and harmful (it
silently dropped child frames before copy-out was complete).

**Also in this commit:** `tgt-vvp/draw_ufunc.c` — added copy-out sequence that
correctly handles the inout-parameter return path for `uvm_config_db::get()`.

**Files:** `vvp/vthread.cc`, `vvp/vvp_net_sig.cc`, `tgt-vvp/draw_ufunc.c`

---

## 3. Constrained Randomization

**Commits:** `ac0e804`, `630699b`, `ed54b52`, `af99114`

---

### 3.1 Unconstrained Randomize (`ac0e804` foundation)

The `%randomize` opcode (added in the broad SV commit) randomizes all `rand`/`randc`
properties by calling the PRNG for each. This forms the basis that constrained
randomization extends.

---

### 3.2 Z3-Based Constraint Solver (`ac0e804`)

**What it does:** Implements IEEE 1800 `constraint` blocks with a real SMT solver
backend, so `randomize()` on an object with constraints produces values that satisfy
all constraints.

**Pipeline:**

1. **`parse.y`** — Grammar for `constraint` block bodies: `inside {[lo:hi]}`,
   `<`, `>=`, nested `if`, `soft` (silently accepted).
2. **`PExpr.h`/`PExpr.cc`** — `PEInside` AST node; binary operator accessors.
3. **`pform_types.h`/`pform_pclass.cc`** — Store constraint expressions on
   `class_type_t`.
4. **`elaborate.cc`** — `pexpr_to_constraint_ir()`: converts AST to S-expression
   IR strings.
5. **`netclass.h`/`netclass.cc`** — Store named constraint IR strings on `netclass_t`.
6. **`ivl_target.h`/`t-dll-api.cc`** — Export `ivl_type_constraints()`,
   `ivl_type_constraint_name()`, `ivl_type_constraint_ir()` API.
7. **`tgt-vvp/draw_class.c`** — Emit `.constraint "name" "ir"` to VVP object file.
8. **`vvp/lexor.lex`/`parse.y`/`class_type.{h,cc}`** — Parse `.constraint` directive,
   store on `class_type`.
9. **`vvp/vvp_z3.{h,cc}`** — Z3 runtime:
   - Fast path: generate random values; if they already satisfy all constraints, keep
     them (preserves variety).
   - Slow path: use `Z3_optimize` with `minimize(bvxor(prop, rand_target))` to find
     the nearest feasible point to the random target.
10. **`vvp/vthread.cc`** — `of_RANDOMIZE` calls Z3 when constraints are present;
    returns a 32-bit result (1 = success, 0 = infeasible).

**Constraint IR format:**
```
(inside p:N:W [c:lo,c:hi])   — property N width W inside range [lo,hi]
(lt p:N:W c:V)               — property N < constant V
(ge p:N:W c:V)               — property N >= constant V
(and expr expr)              — conjunction
```
where `p:N:W` = property index N width W, `c:V` = constant V.

**Tests:** `tests/constraint_test.sv` — 10 iterations, values constrained to 0–99,
all distinct (via Z3 bvxor variety optimization).

---

### 3.3 Inline Constraints: `randomize() with { ... }` (`630699b`)

**What it does:** Implements the SV inline constraint form:

```systemverilog
item.randomize() with { data inside {[0:7]}; };
```

**Mechanism:**
- **`parse.y`** — Grammar for `with { constraint_expression_list }` appended to
  `randomize()` calls.
- **Elaboration** — Caller-scope variables referenced inside `with { }` are captured
  via a slot mechanism: each captured variable gets a `v:N` slot index in the
  constraint IR (e.g., `(inside p:0:32 v:0)` where slot 0 holds the caller's variable
  value). The elaborator emits the slot values as extra arguments to the syscall.
- **`vvp/vthread.cc`** — `of_RANDOMIZE_WITH`: pops the slot values from the stack,
  stores them in a caller-scope slot array, passes it to the Z3 solver alongside the
  object's named constraints.

**Supported patterns:**
- `{ data == 42; }` — constant equality
- `{ data inside {[lo:hi]}; }` — range membership
- `{ data < local_var; }` — caller-scope variable bound
- `{ data inside {val1, val2}; }` — enumerated set

**Tests:** `tests/randomize_with_test.sv` — 4 patterns, all pass.

---

### 3.4 `rand_mode(0/1)` (`ed54b52`)

**What it does:** Implements `obj.rand_mode(0)` / `obj.rand_mode(1)` to disable or
re-enable randomization of all `rand` properties on an object.

**Pipeline:**
- `vvp/vvp_cobject.{h,cc}` — `rand_mode_` per-property bool vector (all `true` by
  default); `rand_mode(pid)` getter, `set_rand_mode(pid, bool)` setter,
  `set_all_rand_mode(bool)`.
- `vvp/codes.h` + `compile.cc` — `%rand_mode` opcode (no args; pops mode from vec4
  stack, pops cobject from object stack).
- `vvp/vthread.cc` — `of_RAND_MODE`: pops mode, pops cobject, calls
  `set_all_rand_mode(mode)`. `of_RANDOMIZE`/`of_RANDOMIZE_WITH` skip properties where
  `rand_mode_[pid] = false`.
- `elaborate.cc` — `rand_mode(en)` task call → `$ivl_class_method$rand_mode` NetSTask.
- `tgt-vvp/vvp_process.c` — `$ivl_class_method$rand_mode` → emit
  `draw_eval_vec4(mode)` + `draw_eval_object(obj)` + `%rand_mode`.

**Also in `ed54b52`:** K_fork scope always-keep fix (see §1.5 above).

**Tests:** `tests/rand_mode_test.sv`

---

### 3.5 `constraint_mode(name, 0/1)` (`af99114`)

**What it does:** Implements per-named-constraint enable/disable, so individual
constraint blocks can be turned off while leaving others active.

**Pipeline:**
- `vvp/vvp_cobject.{h,cc}` — `constraint_mode_` bool vector (all `true`);
  indexed by constraint ID (sequential integer).
- `vvp/codes.h` + `compile.cc` — `%constraint_mode N` opcode (OA_NUMBER = constraint
  index; pops mode from vec4 stack, pops cobject from object stack).
- `vvp/vthread.cc` — `of_CONSTRAINT_MODE`: pops mode, pops cobject, calls
  `set_constraint_mode(cp->number, mode)`.
- `vvp/vvp_z3.cc` — Both constraint loops (fast-path checker and optimizer) skip
  disabled constraints via `cobj->constraint_mode(ci)`.
- `elaborate.cc` — `obj.constraint_name.constraint_mode(mode)` multi-component path:
  extracts constraint name, symbol-searches for object, netclass_t constraint index
  lookup, emits `$ivl_class_method$constraint_mode`. Also handles `obj.constraint_mode(mode)`
  (all-constraints form) by iterating constraint count and emitting one syscall per
  constraint.
- `tgt-vvp/vvp_process.c` — emit `draw_eval_vec4(mode)` + `draw_eval_object(obj)` +
  `%constraint_mode cid`.

**Tests:** `tests/constraint_mode_test.sv`

---

## 4. Virtual Interfaces as Class Members

**Commits:** `98895080`, `8b8d4b0`, `8ca869b` (partial)

Implements `@(posedge vif.clk)` where `vif` is a virtual interface stored as a class
member variable. This is the primary way UVM drivers detect clock edges.

---

### 4.1 `@(posedge vif.clk)` (`98895080`)

**Problem:** A thread that executes `@(posedge vif.clk)` (where `vif` is a class
member holding a virtual interface handle) waits forever. No edge event is ever
delivered.

**Root cause:** `elaborate.cc`'s `nex_input()` traced `@(posedge vif.clk)` through the
`NetEProperty` chain back to `this` (the class object). The event probe connected to
`this`'s nexus, which never fires edge events.

**Fix:** Three-level `NetEProperty` chain detection in `elaborate.cc`:
```
outer_p = NetEProperty(outer, M=clk_idx)   ← .clk property
middle_p = NetEProperty(mid, N=vif_idx)    ← .vif property
root_e = NetESignal(this)                  ← class object
```

When this pattern is detected: `pr->set_vif_posedge(N, M)` propagates the VIF member
index (N) and clock member index (M) through the pipeline.

**New infrastructure:**
- `NetEvProbe` gets `is_vif_posedge_`, `vif_N_`, `vif_M_` fields
- `ivl_event_s` gets same fields; `t-dll.cc` fills them in the POSEDGE case
- `ivl_event_is_vif_posedge()`, `ivl_event_vif_N()`, `ivl_event_vif_M()` API
  functions in `t-dll-api.cc` / `ivl_target.h`
- `tgt-vvp/vvp_process.c` emits the sequence:
  ```
  %load/obj v_this
  %prop/obj N,0          ← load the virtual interface handle from property N
  %pop/obj 1,1
  %wait/vif/posedge M   ← wait for posedge on clock M of that interface
  ```
- `vvp/vvp_vinterface.{h,cc}`: `get_posedge_functor(M)` lazily creates a
  `vvp_fun_edge_sa` linked to the actual signal net inside the `vvp_vinterface`
  object, adds the waiting thread to the functor's wait list.
- `vvp/codes.h`, `vvp/compile.cc`, `vvp/vthread.cc` — `%wait/vif/posedge` opcode.

**Files changed:** `elaborate.cc`, `netlist.h`, `net_event.cc`, `t-dll.h`, `t-dll.cc`,
`t-dll-api.cc`, `ivl_target.h`, `tgt-vvp/vvp_process.c`, `vvp/vvp_vinterface.{h,cc}`,
`vvp/codes.h`, `vvp/compile.cc`, `vvp/vthread.cc`

**Tests:** `tests/vif_probe.sv`

---

### 4.2 `@(negedge vif.clk)` and Anyedge (`8b8d4b0`)

Extends Phase 3 VIF edge detection to `negedge` and unqualified `@(vif.clk)` (anyedge).

**Changes:** Mirrors the posedge path for all three edge types. Three new opcodes:
`%wait/vif/negedge M`, `%wait/vif/anyedge M`. `vvp_vinterface` gains
`get_negedge_functor(M)` and `get_anyedge_functor(M)`.

**Tests:** `tests/vif_negedge_test.sv`

---

## 5. UVM Register Layer

**Commit:** `d9e9bfb`

Fixes `uvm_reg::read()` returning X for the value. Root cause and fix described
in §2.2.

**Also in this commit:**

- **`%load/dar/obj/vec4` opcode:** Reads a vec4 element from a dynamic array that is
  a class property (`obj.darray_prop[i]`). Emitted by
  `tgt-vvp/eval_vec4.c:draw_property_vec4`.
- **`.size()` for darray class properties** in `tgt-vvp/vvp_priv.h`'s
  `draw_sfunc_vec4`.
- **`is_fork_v_child` bit** in thread state for tracking fork/v child threads.
- **`do_CMPU` width mismatch:** Zero-extend instead of assert when operands differ in
  width.
- **`of_CAST_VEC4_STR` runtime-width fix:** Use the runtime string width when it is
  wider than the compile-time width.

**Tests:** `tests/reg_basic_test.sv` — backdoor write `0xab`, read back, mirror all
pass.

---

## 6. Functional Coverage

**Commit:** `4dc9813` (Phase 5 portion)

Implements IEEE 1800 `covergroup`/`coverpoint`/`bins` with runtime sampling and
coverage reporting.

### Frontend

- **`parse.y`** — Grammar for `covergroup`, `coverpoint`, `bins` (value lists, range
  bins, transition bins), `option.field = expr` (silently ignored).
- **`pform_types.h`** — `covergroup_type_t` with port list and sample function.
- **`pform_pclass.cc`** — Register covergroup name as a CLASS typedef; store body.
- **`elaborate.cc`** — Emit coverage sample calls via
  `$ivl_class_method$covgrp_sample`.

### Backend / Runtime

- **`tgt-vvp/vvp_process.c`** — `$ivl_class_method$covgrp_sample` and
  `$ivl_class_method$covgrp_get_inst_coverage` syscall handlers.
- **`vvp/class_type.{h,cc}`** — `.covgrp` assembler directive parsed and stored;
  `class_type` tracks bin hit counts per coverpoint.
- **`vvp/vthread.cc`** — `%covgrp/sample N` and `%covgrp/get_inst_coverage` opcodes:
  - `sample`: pops covergroup object from stack, reads coverpoint values, increments
    bin hit counts.
  - `get_inst_coverage`: counts hit bins / total bins, returns as real.
- **`vvp/codes.h`**, **`vvp/compile.cc`**, **`vvp/lexor.lex`** — new opcodes.

**Tests:** `tests/coverage_basic_test.sv` (50%), `tests/coverage_full_test.sv`
(0→50→100%), `tests/coverage_vals_test.sv` (single-value bins, incremental).

---

## 7. DPI-C Import

**Commit:** `4dc9813` (Phase 6 portion)

Implements `import "DPI-C" function` so SV code can call C functions in shared libraries.

### Frontend

- **`PTask.h`** — `PFunction` gains `is_dpi_import_` and `dpi_c_name_` fields.
- **`parse.y`** — Grammar: `import "DPI-C" [pure/context] function_prototype;`
  sets `is_dpi_import_` and `dpi_c_name_` on the `PFunction`.
- **`pform.h`/`pform_pclass.cc`** — Store DPI function declarations.
- **`elaborate.cc`** — DPI import functions get elaborated but their body is a stub;
  the C name is attached to the `ivl_scope_s`.
- **`ivl_target.h`/`t-dll-api.cc`** — `ivl_scope_is_dpi_import()`,
  `ivl_scope_dpi_c_name()` API.
- **`tgt-vvp/draw_class.c`** — Instead of emitting a VVP function body,
  `draw_dpi_func_body()` emits `%dpi/call/vec4` (or `/real`/`/str`/`/void`).

### Runtime

- **`vvp/vvp_dpi.{h,cc}`** — `ivl_dlopen()` wraps `dlopen`/`LoadLibrary`;
  `ivl_dlsym()` looks up the C function by name.
- **`vvp/main.cc`** — `-d lib.so` flag: loads the shared library at startup; stored
  handle is used by `vvp_dpi.cc`.
- **`vvp/vthread.cc`** — Four new opcodes:
  - `%dpi/call/vec4` — pops int arguments (in declaration order), calls C function,
    pushes int result.
  - `%dpi/call/real` — same for `real`/`double` args and return.
  - `%dpi/call/str` — string return type.
  - `%dpi/call/void` — no return value.

**Tests:** `tests/dpi_basic_test.sv` (`c_add(3,4)=7`, `c_mul(6,7)=42`,
`c_factorial(5)=120`), `tests/dpi_real_test.sv` (`c_sqrt(4.0)=2.0`,
`c_pow(2.0,10.0)=1024.0`). Both require `-d lib.so` when running vvp.

---

## 8. String Methods, Class Arrays, Assoc Array Fixes

**Commit:** `4dc9813`

---

### 8.1 String Methods

**File:** `vpi/v2009_string.c`

Added to the VPI string layer: `toupper()`, `tolower()`, `getc(i)`, `compare(s)`,
`icompare(s)`. These are called via the existing VPI string method dispatch mechanism
(`$ivl_string_method$...`).

---

### 8.2 Class Fixed-Size Array Properties (`int data[N]`)

**Problem:** A class property declared as `int data[8]` (fixed-size unpacked array)
was not allocated or accessible as an array; reads returned 0 and writes were lost.

**Root cause:** `property_atom<T>` in `vvp/vvp_cobject.{h,cc}` did not have an
`array_size_` field; it only allocated a single scalar.

**Fix:** `property_atom<T>` gains `array_size_`; construction allocates a flat array
of that size. Indexed read/write uses `prop_idx * array_size_ + element_idx`.

**Tests:** `tests/class_array_test.sv` — `int data[8]` FIFO, correct order.

---

### 8.3 Assoc Array String-Key Reads (`aa["key"]`)

**Problem:** Reading from an associative array with a string key in a vec4 context
(`int aa[string]; x = aa["key"];`) returned 0.

**Root cause:** `tgt-vvp/eval_vec4.c:draw_property_vec4` emitted `%load/dar/vec4` for
all indexed darray-like accesses, but string-keyed assoc arrays use a different lookup
path.

**Fix:** Added a string-key branch in `draw_property_vec4` that detects when the index
expression is a string literal and emits the correct string-keyed assoc-array load
sequence before falling through to `%load/dar/vec4`.

---

## 9. Grammar Fixes (parse.y)

**Commits:** `2ae0d1d` (scoping), `019e1415` (indexed method calls), `061c7b357`
(Phase 7), `e6328768` (Phase 8), `4aa74ed` (Phase 9)

These commits fix parse.y grammar gaps that prevented real SV code from compiling.
They are the most upstream-ready commits in the branch — each is narrowly scoped and
addresses a specific IEEE 1800 construct.

---

### 9.1 Indexed Object Method Calls (`019e1415` — Phase 1a/1b)

**Problem:** `assoc[key].method()` and `darray[i].method()` produced a syntax error
because the grammar had no rule for an expression like `expr_primary '[' expr ']' '.' IDENTIFIER '(' ... ')'`.

**Fix:** Added `expr_primary '[' expr ']' '.' tf_identifier ...` alternatives to
`subroutine_call` to handle indexed-then-method chains. The elaborator already handled
the underlying `NetEProperty` graph; only the parser rule was missing.

**Files:** `parse.y`, `elab_expr.cc`

---

### 9.2 Phase 7: SV Grammar Fixes for OpenTitan DV (`061c7b357`)

Six `parse.y` gaps and one `elab_type.cc` null-pointer crash:

| Rule | What Was Added | Reason |
|---|---|---|
| `variable_decl_assignment` | Accept `TYPE_IDENTIFIER` as variable name | Parameterized class name reused as variable name |
| `foreach` index | Constant expression for fixed outer dimension | `foreach (arr[const].member[var])` |
| `tf_port_item` | Accept `TYPE_IDENTIFIER` as port name | Port name same spelling as class type |
| `named_expression` | Accept `TYPE_IDENTIFIER` as key | `.PARAM(value)` when params are `TYPE_IDENTIFIER` |
| `virtual_interface_type` | Accept `IDENTIFIER` form | Forward-referenced interfaces not yet `TYPE_IDENTIFIER` |
| `extern constraint` | Accept prototype `extern constraint name;` | Out-of-class constraint body (silently) |
| `package_constraint_declaration` | Out-of-class body `constraint ClassName::name { }` | Allowed at package scope |
| Transition bins | `bins b = (0 => 1);` via `K_EG` token | Coverpoint value transitions |
| Coverage option | `option.field = expr;` as silently-ignored `bins_item` | UVM coverage options |

**`elab_type.cc`:** Null guard in `elaborate_darray_check_type` when element type
elaboration already failed (prevents segfault dereferencing nullptr in error path).

---

### 9.3 Phase 8: OpenTitan DV Packages Through `tl_agent_pkg` (`e6328768`)

Ten more parse.y fixes enabling OpenTitan DV package compilation:

| Rule | What Was Added |
|---|---|
| Multi-line string literals | Bare `\n` in CSTRING → space in `yytext_string_filter` (not "Missing closing quote") |
| Auto-bins `bins name[] = {values}` | `K_bins`/`ignore_bins`/`illegal_bins` empty `[]` variants |
| Package covergroup scoping | `package_cg_port_prefix` non-terminal; pform push unbound scope for port params |
| Covergroup with-function | Factored prefix fixes duplicate-MRA LALR conflict |
| `label_opt` | Accept `TYPE_IDENTIFIER` after `:` (covergroup names become types) |
| `bins b = default` | Default bins form |
| `cross cp1, cp2` | `cross_item_list` production and `covergroup_item` cross rule |
| `constraint A -> soft B` | `K_TRIGGER K_soft` forms in constraint_expression |
| `local::var` | `K_local K_SCOPE_RES` prefix to `hierarchy_identifier` |

**Also:** `PExpr.h`/`PExpr.cc`, `elab_expr.cc`, `elab_lval.cc`, `elaborate.cc`,
`net_assign.cc`, `netmisc.cc`, `pform_types.h` — expression and elaboration fixes for
the new grammar constructs.

---

### 9.4 Phase 9: Further Grammar Fixes (`4aa74ed`)

Additional parse.y grammar fixes and one `ivlpp/lexor.lex` fix:

| Rule | What Was Added |
|---|---|
| `pure virtual task lifetime_opt` | Optional `automatic`/`static` between qualifiers and task name |
| `solve X before Y;` | Constraint ordering directive (silently accepted) |
| `constraint_prototype` | Remove "sorry" error; silently accept static prototypes |
| Labeled cross | `IDENT ':'  cross ...` and `TYPE_IDENT ':' cross ...` forms |
| Cross with body | `cross { illegal_bins/bins binsof(...) ... }` |
| `cross_bins_expr` | `binsof(cp)`, `binsof(cp) intersect {...}`, logical operators |
| `transition_seq_list` | Multiple transition sequences: `(0=>1),(2=>3)` |
| `virtual_interface_type` | Add `parameter_value_opt` for parameterized VIFs |
| `lpvalue` | `package_scope hierarchy_identifier` alternative |
| `K_randcase` | Parse and discard as empty block |
| `package_import_declaration` in `statement_item` | `import pkg::*;` inside task/function (IEEE 1800-2012 §26.7) |
| `ivlpp/lexor.lex` MA_START | Silently ignore `` ` `` (token-paste delimiter in macro args) |

---

## 10. Phase 10 — OpenTitan cip_base_pkg Grammar Fixes (2026-04-25)

**Files:** `parse.y`, `lexor.lex`

This phase extends iverilog's SystemVerilog grammar to compile the OpenTitan
`cip_base_pkg` DV stack — the last major DV package boundary — without errors.
Three grammar gaps were fixed:

### 10a. `pkg::var = expr` — Package-scoped variable assignment

**Root cause:** The assignment rules were placed inside `subroutine_call`
(typed `PCallTask*`) instead of `statement_item` (typed `Statement*`), causing
a C++ type mismatch at compile time.

**Fix:** Moved `PACKAGE_IDENTIFIER K_SCOPE_RES IDENTIFIER '=' expression ';'`
and the `TYPE_IDENTIFIER` variant into `statement_item` after other pkg-scoped
rules. Used `new PEIdent($1, hident, @1.lexical_pos)` to pass the package
pointer directly to the lvalue constructor.

### 10b. `TYPE'(expr)` cast and `TYPE'{...}` aggregate pattern

**`TYPE'(expr)` (type cast):** Added `TYPE_IDENTIFIER '\'' '(' expression ')'`
and `package_scope TYPE_IDENTIFIER '\'' '(' expression ')'` as pass-through
rules in `expr_primary`. Pass-through (just return `$4`) avoids an assertion
failure in `netlist.cc:2359` when enum packed-width mismatches constant width.

**`TYPE'{...}` (aggregate pattern):** The `'` in `my_struct_t'{...}` is NOT a
standalone token — the lexer consumes `'{` as single token `K_LP`. Grammar rule
changed from `TYPE_IDENTIFIER '\'' assignment_pattern` to `TYPE_IDENTIFIER
assignment_pattern` (K_LP is the first token of `assignment_pattern`).

### 10c. `this.randomize() with { ... }` — class handle form

**Root cause:** The `K_with '{' constraint_block_item_list_opt '}'` rule only
existed for `hierarchy_identifier` (starts with IDENTIFIER). `this.randomize`
uses `class_hierarchy_identifier` (starts with `K_this`), which had no `K_with`
alternative.

**Fix:** Added `class_hierarchy_identifier argument_list_parens K_with '{' constraint_block_item_list_opt '}'` rule with the same body as the existing
`hierarchy_identifier` form.

### 10d. `#10_000ns` — Underscore separators in time literals (IEEE 1800 §5.7.1)

**Root cause:** The TIME_LITERAL lexer rule accepted `[0-9][0-9_]*...` but
`get_time_unit()` explicitly rejected strings containing `_`. Additionally,
`atof("10_000ns")` returns 10.0 (stops at `_`) rather than 10000.0.

**Fix:** Strip underscore separators from the matched text in the TIME_LITERAL
lexer action before returning the token. Both `get_time_unit()` and `atof()`
then see the clean numeric string.

### 10e. New exports in `ivl.def` (Windows DLL compatibility)

New API functions from Phases 3, 5, and DPI were missing from `ivl.def`,
which controls which symbols are exported by the Windows DLL:
- Phase 3 (VIF events): `ivl_event_is_vif_posedge/negedge/anyedge`,
  `ivl_event_vif_N/M`
- Phase 5 (coverage): `ivl_type_covgrp_ncoverpoints/bins/bin_prop/lo/hi/cp`
- DPI: `ivl_scope_is_dpi_import`

### 10f. UVM regression tests added to CI

The 22 UVM tests in `tests/` are now tracked in the git repository and run
as a separate `UVM regression tests` step in the GitHub Actions workflow
(`.github/uvm_test.sh`), on all three platforms (Linux, macOS, Windows/MSYS2).

---

## 10b. CI / Build Portability

**Commits:** `4a595c2`, `2f740b2`, `21d0f17`, `d5d50b1`, `6991bd6`, `844be75`,
`20850e9`, `f1244e8`

These commits make the GitHub Actions CI green on all three platforms (Linux, macOS,
Windows/MinGW). They are not SV language changes and are suitable for upstream as-is.

Key fixes:
- **macOS:** `nproc` → `sysctl -n hw.logicalcpu`; `brew --prefix bison` for correct
  bison path; `include <mach-o/dyld.h>` for `_NSGetExecutablePath`.
- **Windows/MinGW:** Python package install for docopt; `execinfo.h` guard;
  symbol export fixes.
- **CI structure:** Separate build phases; Z3 installed on all platforms; Node.js 24
  forced via `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true`.
- **Pre-existing regression:** `automatic_events` test marked NI (not our regression).

---

## 11. Upstream Readiness Summary

| Change Group | Upstream Status | What's Needed |
|---|---|---|
| §1.1 Nested function flow control | **Ready** | Focused commit, has ivtest coverage |
| §1.3 Elaboration ordering | **Needs splitting** | Mixed into large commit |
| §1.4 Callf opcode mismatch | **Ready** | Small focused fix, clean |
| §1.5 Unnamed begin-end scoping | **Ready** | Self-contained parse.y + test |
| §1.2 Broad SV class support | **Needs decomposition** | 25K-line commits; split by sub-feature |
| §2.1 Context warning gating | **Ready** | Small, clear purpose |
| §2.2 Post-join copy-out | **Ready** | Surgical vthread.cc fix, good commit message |
| §2.3 uvm_config_db context chain | **Ready** | Small, clear regression |
| §3.1/3.2 Z3 constraint solver | **Needs discussion** | Z3 is a new hard dependency; needs `configure --with-z3` and optional linkage |
| §3.3 Inline constraints | **Needs discussion** | Depends on Z3; otherwise clean |
| §3.4 rand_mode | **Ready** | Small, correct per IEEE 1800 |
| §3.5 constraint_mode | **Ready** | Small, correct per IEEE 1800 |
| §4 Virtual interface events | **Ready** | Well-structured new opcodes, clean layering |
| §5 UVM register layer | **Needs context** | The vthread fix is upstream-ready; other Phase 4 items need splitting |
| §6 Functional coverage | **Needs discussion** | Coverage is a significant new feature; needs maintainer buy-in on approach |
| §7 DPI-C import | **Needs review** | New opcodes and runtime dlopen; functionally correct but needs CI and ivtest tests |
| §8 String methods | **Ready** | Small additions to existing VPI layer |
| §8.2 Class fixed-size arrays | **Ready** | Isolated fix to property_atom |
| §9 Grammar fixes (all phases) | **Ready** | Each rule addition is narrow and citable to the LRM |
| §10 CI fixes | **Not applicable** | Fork-specific CI; upstream has its own CI |

**Hard blockers for any upstream submission:**
1. Tests must be in `ivtest/ivltests/` with `regress-sv.list` entries, not in `tests/`.
2. The large foundational commits must be decomposed before review is feasible.
3. Z3 dependency must be optional (`configure --with-z3`).

---

## 12. Known Limitations and Deferred Work

### `pkg::var = expr` Assignment (Package-Scoped Lvalue)

**Status:** ✅ Fixed in Phase 10.

Rules moved to `statement_item`; lvalue constructed via `new PEIdent($pkg, hident, @pos)`.
Both `IDENTIFIER` and `TYPE_IDENTIFIER` variants handled.

### `dist` Weighted Distribution

**Status:** Not implemented.

`constraint { data dist { 0:=80, 1:=20 }; }` is parsed but `dist` items are silently
ignored by the Z3 solver. The solver will produce uniform distribution within any
remaining constraints.

### Full UVM Library End-to-End

**Status:** Partial.

The UVM phase infrastructure (phases, objections, sequencer/driver TLM) works.
The UVM factory works. The UVM register layer (basic backdoor) works. Gaps remain in:
- `uvm_field_automation`: `copy()` and `compare()` work; `print()` printer-subclass
  dispatch fires `[NO_OVERRIDE] emit() method not overridden` (audit 2026-05-01)
- `randc` cyclic semantics: behaves as `rand` (Phase 63 candidate)
- Concurrent assertions (`assert property |->`, `|=>`, `disable iff`): silently
  pass-no-op (Phase 62 candidate — false-pass risk)
- `dist` weighting: uniform regardless of weights (Phase 66 candidate)
- `soft` constraints: treated as hard (Phase 66 candidate)
- Streaming operators `{<<{}}` `{>>{}}`: silently produce zero
- `std::randomize(var) with {...}`: `with` clause not parsed
- `uvm_resource_db#(T)::set/read_by_name`: typed-pool path returns 0
- `uvm_cmdline_processor.get_args(args)`: elaboration error on output arg
- `uvm_reg.lock_model()` task missing — blocks register layer beyond raw backdoor
- Coverage `cross` / `illegal_bins`: silently inactive
- User-defined UVM phase (extends `uvm_task_phase`): `exec_task` never called
- `uvm_callbacks::add` registration check warns CBUNREG (dispatch works)
- Tagged unions (`union tagged { ... }`): syntax error
- Some parameterized factory override combinations
- `uvm_reg_frontdoor` (gap: `atomic_lock`, `start`, `atomic_unlock`)

### OpenTitan UART DV — Status After Phase 61d

**Status:** UART smoke vseq advances linearly past prior plateau points. 2-hour
smoke run reaches sim 1.76 ms (vs pre-Phase-61 30 µs hang) with 0 fatals and
1 pre-existing tl_host_driver UVM_ERROR. Smoke does not reach `Finished test
sequence` within the 2 hr wallclock budget — remaining gap is throughput-bound,
not bug-bound.

Issues #29, #30, #31 are all closed. Phase 58 fixed wait()-loop sensitivity.
Phase 59 fixed both try_next_item and class-property staleness as one bug
(autotask self-frame pinning in owned_context). Phase 60 fixed time literals
in class methods (was a major silent bug). Phase 61 series fixed three
performance pathologies in the runtime that previously hung smoke at sim 30 µs.

#### Phase 58 — wait()-loop sensitivity through VIF signal chain (`3bd688e9b`)

Two distinct bugs landed as one phase. (a) `elaborate.cc:try_set_vif_anyedge`
only recursed through `NetEBinary`; extended to `NetEUnary` (covers `!` and
`NetEUReduce`) and `NetESFunc` (covers `$isunknown`/`$past`/`$rose`/`$fell`/
`$stable`/`$countbits`/`$onehot`). (b) `vvp/vpi_vthr_vector.cc::__vpiVThrVec4Stack
::vpi_get_value_vector_` did not zero the result buffer, so bval bits beyond
the value's width carried over from prior VPI calls (mirror `format_vpiVectorVal`
in `vpi_signal.cc` via `memset`). Repro: `tests/wait_vif_isunknown_test.sv`.

#### Phase 59 — Pin autotask self-frame in owned_context on fork (`2d4432afb`)

Trace via `IVL_VDISPATCH_TRACE=1 IVL_LOAD_STR_TRACE=a_channel_thread` showed
`vthread_get_rd_context_item_scoped` returning nil on the second iteration of
a forever loop in a forked autotask: the autotask's own frame was no longer on
any of the running thread's chains (wt, rd, owned), so `@`-slot reads fell
through to nil and cascaded down through `port → m_if → _ivl_414.try_next_item`
virtual dispatch, hitting the base error stub. Fix in `vvp/vthread.cc::of_FORK`:
when launching an automatic-scope child task, pin the just-allocated autotask
frame as a retained self-reference in `child->owned_context`.

The owned-chain fallback in `vthread_get_rd_context_item_scoped` then always
finds the autotask's own context, even after intervening sub-call activity has
pruned wt/rd. Closes #30 (try_next_item dispatch) AND #31 (cfg=null fork core
dump) — same root cause.

#### Phase 59 perf — Single-frame autotask retain (`098f2e1f7`)

`retain_context_chain_(thr->wt_context)` was walking the entire stacked context
chain on every autotask fork (one hash insert per entry). For OT-class
testbenches with deep fork chains, this turned every fork into O(N) hash-update
work. Replaced with `retain_automatic_context_(thr->wt_context)` (single hash
insert for just the head). Sim time advance jumped from ~10 ns/s wall-clock to
~70 ns/s for OT smoke.

#### Phase 60 — Time literals in class methods respect file timescale (`1b80ea624`)

Before this fix, time literals like `100ns` parsed inside a class method
evaluated to 0, and `#100ns` advanced 1e9 times too far (treated as 100s).
Root cause: `PClass` is a `PScopeExtra` and gets its `time_unit/precision`
from the parent's at PClass-creation time via `pform_set_scope_timescale`.
The parent of a file-level class is the compilation unit (`$unit`), whose
`time_unit` gets initialized to `def_ts_units` (default 0 = "1 second")
rather than the file's `` `timescale`` value. Fix in two places:

1. `pform_set_scope_timescale(scope, parent)`: when the parent's `time_unit`
   is the default but a `` `timescale`` directive is in effect, propagate the
   directive's unit to the scope.
2. `pform_get_timeunit/prec`: walk up the scope chain via
   `find_scopex_with_explicit_time_unit_/prec_` looking for non-default;
   fall back to `pform_time_unit`.

#### Phase 61 — anyedge_aa::recv_object recursive fallback skip (`ab5e1b7c0`)

`vvp_fun_anyedge_aa::recv_object` had a fallback at `event.cc:888` that ran
when context recovery returned null: iterate `context_scope_->live_contexts`
and recursively invoke `recv_object` for every live context. In OT-class
testbenches with deep fork chains stacking thousands of automatic contexts,
each recursive call did its own O(K) `vthread_recover_context_for_scope` chain
walk — total O(K²) per @-event delivery. Smoke vseq hung at sim ~30 µs with
100% CPU and zero minfaults.

Captured via two SIGUSR1 dumps showing the hot stack:
`STORE_PROP_*` → `notify_signal_aliases` → `vvp_fun_signal_object_aa::recv_object`
→ recursive `vvp_fun_anyedge_aa::recv_object` → memmove. Fix: gate the
recursive call on `state->threads != null` — anyedge_aa only wakes threads,
doesn't store, so contexts with no waiters can be skipped.

#### Phase 61b — Hoist bounds check from anyedge_aa fallback (`86ee43659`)

Phase 61 left an O(K) iteration where each step called `vvp_get_context_item`
which calls `malloc_usable_size`. All live contexts of the same scope have
the same allocation size, so one head check suffices. Eliminates K calls to
`malloc_usable_size` per delivery.

#### Phase 61c — O(1) suffix index for runtime virtual-dispatch (`d49afb836`)

`runtime_lookup_code_scope_by_suffix_` linearly scanned `runtime_code_scope_map`
on every miss in the direct-name lookup. SIGUSR1 sample backtraces showed it
as 17/30 frames (~57%) — tied with `of_FORK_V` for hottest non-runtime symbol.
Each `maybe_dispatch_virtual_method_call_` walks the class hierarchy chain,
multiplying the cost. Built a parallel `std::map<suffix, vector<key>>` index,
lazily populated on first miss and rebuilt when the source map grows. Lookup
is now O(log N).

#### Phase 61d — Bypass malloc_usable_size in signal_object_aa slot getter (`2a1680d41`)

After Phase 61c, sample histogram shifted to make
`vvp_fun_signal_object_aa::recv_object` the hottest non-runtime symbol (19/30).
Each call goes through `signal_object_aa_get_or_make_slot` → `vvp_get_context_item`
(with `malloc_usable_size`). `context_idx_` is set at compile time and is
guaranteed valid; the bounds check is purely defensive.

#### Phase 61 series performance summary

| Stage | Smoke @ 10 min | Multiplier vs prior |
|---|---:|---:|
| Pre-Phase-61 | 30 µs (hang) | — |
| Phase 61 | ~210 µs | 7× |
| Phase 61b | ~270 µs | 1.3× |
| Phase 61c | ~590 µs | 2.2× |
| Phase 61d | ~590 µs | 1.0× (bypass cheap relative to recovery) |

Phase 61 stack reaches sim 1.76 ms in 2 hr. Average ~244 ns/s wallclock with
slowdown in the byte-transfer phase (UART RTL clocks dominate). Reaching
smoke completion within minutes would require iverilog event-loop work
measured in weeks (lock-free scheduler, JIT, or similar fundamental changes).

#### vvp SIGUSR1 dump handler (`a7b8a0db8`)

Send `kill -USR1 <vvp_pid>` to print the currently-running vthread (scope/pc/
state via `vthread_dump_running_thread`) plus a C-level backtrace via
`backtrace_symbols_fd`. Works around `ptrace_scope=1` environments where gdb
attach fails. Used to identify Phase 61's hot loop. Sample histogram via:

```bash
grep -oE "_Z[A-Za-z0-9_]+" smoke.log | c++filt | sort | uniq -c | sort -rn
```

#### vvp diagnostic env vars (`ae6e5afad`)

- `IVL_SAME_TIME_LIMIT=N` — bail with stack dump after N consecutive same-sim-time
  events (zero-time-spin watchdog).
- `IVL_TIME_TRACE_NS=N` — print `TIMETRACE @ X ps` every N ns of sim-time advance.

Both env-gated; no overhead when unset.

#### vvp scoped-read fast path (`6d12cd552`)

`vthread_get_rd_context_item_scoped` was unconditionally walking three chains
via `first_live_context_for_scope` even when the head context already matched
the scope. Reorganized to only walk the chains when both heads (wt/rd) miss.

### OpenTitan `lc_ctrl_pkg.sv` and `tlul_pkg.sv`

**Status:** ✅ Compile cleanly as of Phase 9.

```bash
iverilog -g2012 -I hw/ip/prim/rtl \
  hw/ip/prim/rtl/prim_util_pkg.sv \
  hw/ip/prim/rtl/prim_mubi_pkg.sv \
  hw/ip/lc_ctrl/rtl/lc_ctrl_state_pkg.sv \
  hw/ip/lc_ctrl/rtl/lc_ctrl_pkg.sv \
  -o /dev/null
```

`cip_base_pkg.sv` and `tl_agent_pkg.sv` also compile through Phase 8.

---

## 13. Commit Index

All 86 commits ahead of `steveicarus/iverilog` `master`:

| Hash | Phase | Description |
|---|---|---|
| `fc8e3db91` | 62e | C6 — Parse `std::randomize(var) with{}` as bare statement and void'() form |
| `9e9dd8eb8` | 62d | C5 — Streaming concatenation operators (RHS bit-reverse and chunk-reverse) |
| `314b3a38c` | 62c | I4 — Soft constraints via Z3_optimize_assert_soft |
| `6b3300cb5` | 62b | C7 — Dist weighting via Z3 soft assertions per branch (real probabilistic semantics) |
| `5eff7c48f` | 62a + I7 | C1 randc cyclic randomization (per-property history bitmap); silence vvp_queue_object get_word warning |
| `b9450999b` | 62 / I6 | Parse tagged union (treated as plain union; semantics unenforced) |
| `e66a4ad5e` | 61e | Bypass malloc_usable_size globally in vvp_get_context_item |
| `2a1680d41` | 61d | Bypass malloc_usable_size in signal_object_aa slot getter |
| `d49afb836` | 61c | O(1) suffix index for runtime virtual-dispatch lookup (replaces O(M) linear scan) |
| `86ee43659` | 61b | Hoist malloc_usable_size bounds check from anyedge_aa fallback loop |
| `ab5e1b7c0` | 61 | Skip recv_object recursive delivery to non-waiting contexts (closes 30 µs smoke hang) |
| `a7b8a0db8` | Diag | vvp SIGUSR1 dump handler (vthread state + C backtrace; works around ptrace_scope=1) |
| `1b80ea624` | 60 | Time literals in class methods now respect file timescale (`#100ns` was 1e9× too long) |
| `6d12cd552` | Perf | Defer chain-walk fallbacks in `vthread_get_rd_context_item_scoped` |
| `098f2e1f7` | 59-perf | Retain only head autotask frame on fork (was O(N) chain walk per fork) |
| `ae6e5afad` | Diag | Env-gated zero-time-spin watchdog and time-advance trace (`IVL_SAME_TIME_LIMIT`, `IVL_TIME_TRACE_NS`) |
| `2d4432afb` | 59 | Pin autotask self-frame in owned_context on fork (closes #30 + #31) |
| `3bd688e9b` | 58 | wait()-loop sensitivity through VIF signal chain (NetEUnary/NetESFunc recursion + vec4 buffer zero) |
| `0b64ab3e8` | 56 | Z3 BV/Bool sort coercion in randomize logical ops (`(not x)` → ITE BV[1]; `and`/`or` operands coerced via `(a != 0)`) |
| `66e5e80a4` | 55 | Same-scope `@cb` (clocking-block) event resolution via scope-walk lookup of pform `Module::clocking_blocks` |
| `a085db844` | 54 | Deferred interface task dispatch via tgt-vvp late binding (`$ivl_iface_late$<iface>$<method>` NetSTask; pform default args evaluated in caller scope) |
| `0e196c4fd` | 50d/e/f | Queue push_back element-type dispatch; pre/post_randomize hook emission; assoc-read via class-property chain |
| `54ffdb9d3` | 53 | Parameterized-class body deferral, rand assoc-vec4 randomization, wait_fork descendants reparenting |
| `a735e6273` | 52 | Autofunction copy-out fix and get_func fork-body walk |
| `e0716e3f0` | 50 | Skip `_ivl_N` suffix in VVP runtime dispatch |
| `48108152a` | 51 | `$value$plusargs` to class string property via `&CPS` VPI handle |
| `6c26198c1` | 8 | Lower `dist` constraint ranges to `inside` |
| `11ba528` | 33 | `sequence`/`property` declarations parse via error recovery; body dropped |
| `382961c` | 32 | `default disable iff (...)` and `default clocking ... endclocking` parse silently at module scope |
| `6b9509b` | 31 | `assert property (... \|-> ...)` and `\|=>` parse without erroring; gn_unsupported_assertions defaults to false |
| `ca20d7a` | 30 | `dist` weighted constraint: drop silently instead of returning lhs (would crash randomize) |
| `9aeecf4` | 29 | README: dvsim runs all 3 UART vseqs to TEST PASSED CHECKS |
| `89fcf58` | 29 | OpenTitan UART DV runs end-to-end through dvsim+fusesoc (bind, case-inside, multi-dim packed param flatten, +plusarg reorder, wildcard-import shadow) |
| `8edd029` | 28 | dvsim+fusesoc integration for OpenTitan DV — driver accepts `+define+`/`+incdir+`, packed-array-param flatten |
| *(pending)* | 10 | cip_base_pkg: TYPE cast, this.randomize with, time underscores, ivl.def |
| `4aa74ed` | 9 | Grammar fixes for lc_ctrl_pkg and tlul_pkg compilation |
| `e632876` | 8 | OpenTitan DV packages compile through tl_agent_pkg |
| `061c7b3` | 7 | SV grammar fixes for OpenTitan DV package compilation |
| `4dc9813` | 5+6 | Functional coverage, DPI import, string methods, class array properties |
| `d9e9bfb` | 4 | UVM register layer — post-join copy-out fix |
| `af99114` | 2 | constraint_mode() per-named-constraint enable/disable |
| `289ef9b` | 1d | Automatic-context recovery warnings behind IVL_AUTO_CTX_WARN |
| `8ca869b` | 3 | uvm_config_db virtual interface passing — context chain fix |
| `8b8d4b0` | 3 | @(negedge vif.clk) and @(vif.clk) anyedge |
| `844be75` | CI | Force GitHub Actions to use Node.js 24 |
| `98895080` | 3 | @(posedge vif.clk) for virtual interface class members |
| `ed54b52` | 2 | rand_mode() and fork scope in functions |
| `6991bd6` | CI | Split build phases; make regression tests non-gating |
| `20850e9` | Build | macOS: include mach-o/dyld.h for _NSGetExecutablePath |
| `f1244e8` | Build | Fix CI: Windows symbol exports, macOS Z3 paths, scope naming |
| `630699b` | 2 | randomize() with { ... } inline constraints |
| `d5d50b1` | CI | Install Z3 on all platforms |
| `21d0f17` | Build | Cross-platform CI fixes; automatic_events pre-existing bug NI |
| `4a595c2` | CI | Trigger on main branch instead of master |
| `019e1415` | 1a/1b | Indexed object method calls; CI workflow portability |
| `2ae0d1d` | 1c | Unnamed begin-end block scoping; event/test improvements |
| `2f740b2` | Build | Fix CI: VVP examples; remove clang ambiguous casts |
| `ac0e804` | 2 | Z3-based constrained randomization (rand/constraint) |
| `5f2bbb9` | 1 | callf opcode mismatch: use scope return type |
| `c82e37e` | 1 | UVM class elaboration ordering |
| `5a4ae98` | Doc | Merge PR #2 (README update) |
| `2ca7d41` | 1 | vvp/compile.cc: unresolved net reference handling |
| `da31167` | 1 | Fix two regression bugs breaking VPI tests |
| `38f8f25` | Meta | Add install/ to .gitignore |
| `4fb6214` | Doc | Merge PR #1 (README update) |
| `d586db4` | Doc | Correct run phase status |
| `79dfc6e` | Doc | README: detailed UVM progress |
| `96ff395` | 1 | Compile warnings fix; SV mailbox/randomize runtime |
| `95a9b32` | 1 | UVM string queue join: pkg::fn calls within same package |
| `3349f35` | 1 | UVM factory registration: $init threads for specialized classes |
| `80877c2` | 1 | Compilation hang: recursion guard, stable specialization cache |
| `0b0ad1b` | Doc | Fork warning to README |
| `6f9373e` | 1 | Snapshot SystemVerilog and UVM enablement fixes |
| `6214779` | 1 | UVM runtime dispatch and call context handling |
| `982b56f` | 1 | Advance SystemVerilog and UVM compatibility |
| `5b45ab3` | 1 | Fix nested function loop flow control |
