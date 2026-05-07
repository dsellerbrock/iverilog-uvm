---
name: UVM and IEEE-1800 SystemVerilog gap audit (2026-05-02)
description: Comprehensive prioritized inventory of remaining iverilog gaps after the I1/I2/I4/I5/C1-C7/I6/I7/B1-B8/Q-method/Phase61 work. ~70 distinct gaps from probe-driven discovery + source TODO/sorry/fallback triage. Each entry tagged VERIFIED-FAILS (reproducer in /tmp/audit_2026_05/) or REVERIFY (source-grounded but not probed).
type: project
originSessionId: 3eb4c85e-78b0-4475-96cd-5139307107dc
---
# Methodology

- **Probes** in `/tmp/audit_2026_05/p*.sv` (99 files): each compiles+runs through `iverilog/install/bin/{iverilog,vvp}` with UVM include path. Results saved to `p*.log`.
- **Source-grounded** entries cite `file:line` of `sorry:` strings or `Compile-progress fallback` comments where I did not write a fresh probe.
- Tags: **VERIFIED-FAILS** = reproducer in /tmp/audit_2026_05/ exhibits the failure. **REVERIFY** = source comments or single-line evidence indicate a gap but I didn't run a probe.
- Out of scope: vhdlpp, tgt-vhdl, tgt-blif, tgt-pcb, syn-rules (all skipped).

Iverilog under test: `Icarus Verilog version 13.0 (devel) (s20251012-102-g9b44d55e9-dirty)` at `/home/daniel/uvm_iverilog/iverilog/install/bin/`.

# Critical (blocks common UVM patterns)

### G01 clocking blocks outside interface — HARD CRASH (assertion + core dump)
- Symptom: declaring `clocking ... endclocking` in a `module` or `program` block yields `error: clocking declarations are only allowed in interfaces.` followed by `assert: pform.cc:3874: failed assertion scope && scope->is_interface` and `Aborted (core dumped)`. IEEE 1800-2017 §14.3 explicitly permits clocking in module, interface, program, and checker.
- Probe: p01_clocking_skew (VERIFIED-FAILS), p02_program_block (VERIFIED-FAILS).
- Location: pform.cc:3874.
- Layer: parser/pform.
- Complexity: small if just lifting the assertion to an error; larger to actually plumb through code-gen.
- Blocks: any module-level clocking + program blocks.

### G02 program blocks parse but reject clocking inside
- Symptom: program block parses but clocking inside fails the same `is_interface` assertion as G01.
- Probe: p02_program_block (VERIFIED-FAILS).
- Location: pform.cc:3874.
- Layer: parser/pform.
- Complexity: same fix as G01 widens the predicate.
- Blocks: program blocks (24.2 testbench style).

### G03 `let` declarations always rejected as `sorry:`
- Symptom: `let MAX(a,b) = (a>b)?a:b;` produces `sorry: let declarations (MAX) are not currently supported.`
- Probe: p03_let (VERIFIED-FAILS).
- Location: pform.cc:3543.
- Layer: parser/pform.
- Complexity: medium (must lower `let` to inline expression at call sites — not a pre-existing function).
- Blocks: cleaner UVM macro expansions; not load-bearing for any one testbench.

### G04 `bind` instance binding hits syntax error
- Symptom: `bind dut checker chk();` gives `syntax error / I give up.` at the `bind` keyword.
- Probe: p04_bind (VERIFIED-FAILS).
- Location: parse.y (no `bind` rule observed); search confirms not implemented.
- Layer: parser.
- Complexity: deep — needs target-instance resolution + replicated elaboration.
- Blocks: testbench monitors that DV teams traditionally inject into RTL via `bind`.

### G05 `assert property` without explicit clocking → "always without delay" elab error
- Symptom: a property without `@(posedge clk)` produces `error: always process does not have any delay.` (because parse.y:2375 lowers concurrent assert to a bare always block).
- Probe: p05_property_seq (VERIFIED-FAILS), p65_sequence_op (VERIFIED-FAILS).
- Location: parse.y:2375 (lowering wraps in always; without clocking event nothing creates the wait).
- Layer: parser→elab interaction.
- Complexity: medium — need a synthetic delay or warn-and-skip if no clocking is found.
- Blocks: SVA assertions written without an explicit `@(posedge clk)` (very common idiom in DV teams that rely on default clocking).

### G06 SVA sequence operators `and`/`or`/`intersect`/`throughout`/`within` not synthesized
- Symptom: same "always without delay" elab error or silent miss; sequence operators are not lowered.
- Probe: p65_sequence_op (VERIFIED-FAILS), p60_concurrent_arg (VERIFIED-FAILS — concurrent assertion in always block syntax error).
- Location: parse.y:2388,2433,2447 (`sorry: concurrent_assertion_item not supported` for procedural form); SVA runtime is largely stubbed.
- Layer: parser+elab.
- Complexity: deep — each operator needs its own runtime semantics.
- Blocks: SVA-heavy verification.

### G07 `process::self()` returns null/incomplete process handle; status is enum-typed but `.name()` and proper status updates missing
- Symptom: `process::self()` populates a handle, but `p.status()` always returns 0 (RUNNING enum value) even after `p.kill()`. `status().name()` doesn't compile if no field-name lookup is set up; have to compare to int values.
- Probe: p08_process (VERIFIED-FAILS — kill() doesn't update status).
- Location: vvp/vthread.cc process introspection (see context around `vvp_object` for process handles).
- Layer: runtime.
- Complexity: medium — process state machine isn't fully wired.
- Blocks: dynamic process control common in stimulus/checker shutdown flows.

### G08 `event.triggered` race with `@(event)` — only one of two waiters fires
- Symptom: `wait (e.triggered)` and `@(e)` queued in parallel — the trigger only wakes one (the `@(e)` one); the `wait (e.triggered)` waiter never fires.
- Probe: p12_event (VERIFIED-FAILS — hits=1, expected 2).
- Location: vvp/event handling.
- Layer: runtime.
- Complexity: medium.
- Blocks: synchronization patterns.

### G09 `foreach (aa[k1, k2])` over assoc-of-assoc body never executes
- **STATUS: FIXED (Phase 77)**
- Symptom: comma-form foreach iterates 0 times even when both inner assocs have entries (`total=0` instead of 33). Bracket form gets a syntax error.
- Probe: p15_foreach_assoc_2d (VERIFIED-FAILS), p15b_foreach_assoc_brack (VERIFIED-FAILS, syntax error).
- Location: elaborate.cc `PForeach::elaborate_assoc_array_` — when `index_vars_.size() > 1` and element type is an inner assoc, build nested `%aa/first/str + %aa/next/str` loops instead of falling through to integer for-loop.
- Fix: `tests/g09_foreach_assoc2d_test.sv` PASS (119 passed, 0 failed regression).
- Layer: parser+elab.
- Complexity: medium (multi-dim assoc is its own iteration shape).
- Blocks: any pattern using nested assoc maps (UVM tracks several).

### G10 queue `.sum()`, `.product()`, `.min()`, `.max()`, `.unique()`, `.unique_index()`, `.and()`, `.or()`, `.xor()`, `.find()`, `.find_index()` — context-sensitive; some forms emit `not a queue method` errors
- Symptom: `q.sum()` reports `error: Method sum is not a queue method.` Same for product. Probe got `Variable item does not have a field named: index.` for `with (item.index)`. The Phase-63b B-series only added some shapes.
- Probe: p16_queue_with (VERIFIED-FAILS), p30_array_methods (VERIFIED-FAILS for .min/.max/.sort on non-queue), p87_unique_index (PASS for queue).
- Location: elab_expr.cc:8857-8911 (sorry: cluster for non-queue array methods); also `with (item.index)` codepath separately broken in elab_expr.cc.
- Layer: elab.
- Complexity: medium (each is its own bytecode template; pattern is established in B1).
- Blocks: standard idioms in scoreboard reductions, RAL frontdoor.

### G11 `solve…before` partially works, but `a -> b == K` implication is dropped
- Symptom: histogram split is correct (a=0 and a=1 both occur ~25 times in 50), but the implications `a -> b == 100` and `a == 0 -> b == 0` are NOT applied. Most iterations show b at random non-100 values.
- Probe: p17_solve_before (VERIFIED-FAILS).
- Location: constraint pipeline (elab_expr.cc constraint nodes + Z3 backend).
- Layer: codegen+runtime constraint solver.
- Complexity: medium (implication requires conditional Z3 assertion).
- Blocks: realistic constraint-based verification.

### G12 `streaming LHS`: `{>>{a,b,c,d}} = src` puts everything in `a` (last lvalue wins); other lvalues stay zero
- Symptom: `{>>{a,b,c,d}} = 32'hAABBCCDD` produces `a=dd b=00 c=00 d=00` (only a is written, with bottom byte).
- Probe: p23_streaming_lhs (VERIFIED-FAILS).
- Location: elab_lval.cc — the streaming-pattern LHS path; phase63b notes acknowledge "LHS streaming deferred."
- Layer: elab.
- Complexity: medium (mirror of Phase63b/C5 RHS streaming, requires per-slice store).
- Blocks: packet pack/unpack patterns common in RAL and bus drivers.

### G13 packed-struct `'{default: 4'hF}` only fills first member
- Symptom: `bw.words[2] = '{default: 4'hF}` results in `bw.words[2].a == 4'hF` but `bw.words[2].b` likely 0; full-pack expected `'{a: 4'hF, b: 4'hF}`. Hex dump of `bw` shows `000f` instead of `00ff` for that slot.
- Probe: p33_packed_struct (VERIFIED-FAILS).
- Location: elab_expr.cc PEAssignPattern struct/default handling.
- Layer: elab.
- Complexity: medium.
- Blocks: RAL field bit-vector init, common pattern in scoreboards.

### G14 array `'{default:'{...}}` — typed-default dropped on assignment-pattern with packed inner type
- Symptom: similar to G13 — `'{int: 0, default: 8'hFF}` triggers `Malformed statement` syntax error; the typed-default form (`type: value`) doesn't parse.
- Probe: p93_assignment_pattern (VERIFIED-FAILS — line 20 typed-default).
- Location: parse.y assignment_pattern rules.
- Layer: parser.
- Complexity: medium.
- Blocks: clean defaulting in field-rich uvm_objects.

### G15 implication `->` constraint not enforced (basic)
- Symptom: `(x == 0) -> (y == 99)` produces y values all over the int range when x==0; same for `(x != 0) -> (y inside ...)`. Range constraints work, implication does not.
- Probe: p24_constraint_dist_more (VERIFIED-FAILS).
- Location: Z3 constraint backend + elab_expr.cc implication codegen.
- Layer: codegen+runtime.
- Complexity: medium.
- Blocks: any non-trivial constraint program.

### G16 `foreach(arr[i]) arr[i] inside {[i*10:i*10+5]}` — index-dependent constraints not enforced
- Symptom: `arr[2]=0`, `arr[3]=0` consistently when constraint says they should be in `[20:25]` and `[30:35]`. Only the first array element occasionally gets a non-zero from the implication chain; rest stay at 0.
- Probe: p24_constraint_dist_more (VERIFIED-FAILS).
- Location: same as G15; foreach-over-rand-array constraint codegen — Phase 50c entry in MEMORY.md (still open).
- Layer: codegen+runtime.
- Complexity: deep — needs runtime expansion of foreach over actual array indices fed to Z3.
- Blocks: array-of-fields randomization (common in packet-class definitions).

### G17 `if-block constraint` syntax: nothing inside the `if(cond) { ... }` block is enforced
- Symptom: `if(cond==1){ x inside {[100:200]}; y inside {[1:5]}; }` else `{ ... }` — every iteration fails both branches (`t=0 f=0` over 40 iterations).
- Probe: p45_constraint_imp_block (VERIFIED-FAILS).
- Location: same as G15.
- Layer: codegen+runtime.
- Complexity: medium.
- Blocks: structured constraint blocks.

### G18 `inside {enum_set}` constraint excluded values still picked
- Symptom: `c inside {RED, BLUE, MAGENTA}` over 60 iterations yields GREEN=8 and YELLOW=10 (both supposed to be excluded).
- Probe: p82_constraint_enum (VERIFIED-FAILS).
- Location: constraint backend — enum value propagation to Z3.
- Layer: codegen+runtime.
- Complexity: medium.
- Blocks: enum-typed RAL fields.

### G19 dist `:/` weighted bin not picked
- Symptom: `x dist {0:/40, 1:/40, 2:/20}` over 100 iterations: x=0:52, x=1:48, x=2:0. The `:/` (range-weight) form silently drops x=2 entirely. Only `:=` form (per-value weight) seems wired in C7.
- Probe: p44_dist_sample (VERIFIED-FAILS).
- Location: dist constraint codegen — the C7 fix only handled `:=`, not `:/`.
- Layer: codegen+runtime.
- Complexity: small (parallel to `:=` codepath).
- Blocks: common dist syntax.

### G20 `rand`-on-extends: child class `rand` properties + parent constraints not solved together
- Symptom: child `C extends P` with `rand int y; constraint cC { y == x*2; }` and parent `rand int x; constraint cP { x inside {[1:50]}; }` — y comes back as random int (1801979802 etc.), constraint `y == x*2` ignored.
- Probe: p98_class_inherit_constr (VERIFIED-FAILS).
- Location: elaborate.cc / class_type rand-property merge across inheritance.
- Layer: elab.
- Complexity: medium — needs to flatten constraint scopes before passing to Z3.
- Blocks: any UVM stimulus class hierarchy.

### G21 `rand int arr[]` size-constraining `arr.size() == sz` ignored
- Symptom: constraint `sz inside {[3:5]}; arr.size() == sz` produces randomized sz but arr.size always 0.
- Probe: p71_constraint_with_array (VERIFIED-FAILS).
- Location: dynamic-array sizing in randomize — needs runtime resize hook.
- Layer: runtime.
- Complexity: medium.
- Blocks: payload-size-rand patterns.

### G22 `factory.create_object_by_name` and `uvm_factory::get().create_object_by_name` both unresolvable
- Symptom: both `factory.create_object_by_name(...)` (UVM global) and `uvm_factory::get().create_object_by_name(...)` (canonical IEEE 1800.2 path) report `error: No function named 'create_object_by_name' found in this context.` `set_type_override_by_name` warns "Enable of unknown task ignored (compile-progress)." Confirmed working: `T::type_id::create("name")` (registry-style).
- Probe: p25_uvm_factory_create_name (VERIFIED-FAILS); p96_uvm_obj_factory (PASS — type_id::create + set_type_override).
- Location: elab_expr.cc class-method dispatch on the singleton-returning factory accessor.
- Layer: elab.
- Complexity: medium — singleton-returning function-call result needs class-method dispatch.
- Blocks: dynamic factory lookup by string (common in scoreboards / config-driven test selection).

### G23 `uvm_register_cb(T, my_cb)` macro corrupts class layout
- Symptom: a class with `\`uvm_register_cb(T, my_cb)` triggers 15+ cascading errors at elaboration: "first is not a method of class T," "type of variable 'item' doesn't match," "I don't know how to elaborate assignment_pattern expressions for class T{netvector_t:bool unsigned m_register_cb_my_cb}." The macro adds a member that breaks downstream class-property iteration.
- Probe: p28_uvm_callbacks_dyn (VERIFIED-FAILS).
- Location: probably the class-properties-iteration (macros/uvm_callbacks_macros.svh expansion creates a property whose type elaborates as netvector_t:bool — wrong); related to the stale I5 entry.
- Layer: macros + elab.
- Complexity: deep.
- Blocks: dynamic callback-based UVM patterns.

### G24 `uvm_config_db#(class_obj)::get` returns false for class-typed objects
- Symptom: `set` followed by `get` of a class object via `uvm_config_db` returns 0 — the get fails silently. Int and string forms work.
- Probe: p95_uvm_seq_cfg (VERIFIED-FAILS).
- Location: deep in uvm_config_db parameterized-set/get; likely a class-handle stored as `uvm_object` then $cast back fails for derived types.
- Layer: runtime + class type-erasure.
- Complexity: medium-deep.
- Blocks: passing config objects through UVM hierarchy (very common).

### G25 `uvm_field_sarray_int` (and likely `uvm_field_array_*`) does not propagate values during clone/copy
- Symptom: cloning an object with a static array field via `uvm_object_utils_begin/end + uvm_field_sarray_int` yields the clone with arr=0..0 even though the source has values. `print()` shows the clone's array entries all 'h0.
- Probe: p72_uvm_field_macros (VERIFIED-FAILS).
- Location: macros/uvm_object_defines.svh field-macro expansion; the `do_copy` virtual override for sarray fields is incomplete or hits a vvp_darray type-mismatch.
- Layer: runtime (vvp_darray) + UVM macro expansion.
- Complexity: medium.
- Blocks: any UVM transaction class with byte-array payloads (90% of testbenches).

### G26 modport task/function ports = `sorry:`
- Symptom: `modport mst (input data, import do_write);` emits `sorry: modport task/function ports are not yet supported.`
- Probe: p55_modport_func (VERIFIED-FAILS).
- Location: parse.y:4192,4199.
- Layer: parser.
- Complexity: medium.
- Blocks: real-DV interface APIs that wrap drive sequences as tasks.

### G27 modport `producer p(a)` — implicit modport selection at port bind missing
- Symptom: `producer p(a)` (where `a` is `my_if`) requires explicit `producer p(a.mst)`; otherwise compile error claims signal is `uwire` (interface signal direction defaulting wrong).
- Probe: p99_iface_modport_bind (VERIFIED-FAILS).
- Location: elaborate.cc port-connection code for interface ports.
- Layer: elab.
- Complexity: medium.
- Blocks: simpler RTL patterns that omit the explicit modport selector.

### G28 `interface b[4](); virtual bus_if vifs[4];` interface array at port site = `Invalid module item`
- Symptom: `bus_if b[4]();` (interface instance array) yields `syntax error / Invalid module item.` from parse.y line 9.
- Probe: p21_iface_array (VERIFIED-FAILS).
- Location: parse.y interface-instantiation rules.
- Layer: parser.
- Complexity: medium.
- Blocks: arrayed lane / multi-channel testbench shapes.

### G29 `interface bus_if; modport mst(...); modport slv(...); endinterface` + `producer p(b.mst);` + `consumer c(b.slv);` style — `Net b.mst is not defined in this context`
- Symptom: instance modport-select bind syntax (`b.mst`) at module instantiation reports the modport name unresolved.
- Probe: p43_iface_inh (VERIFIED-FAILS).
- Location: elaborate.cc port-connection.
- Layer: elab.
- Complexity: medium.
- Blocks: classic master/slave/monitor split via modports.

### G30 svdpi.h (and svOpenArrayHandle entire surface) not shipped or installed
- Symptom: `find /home/daniel/uvm_iverilog/iverilog -name 'svdpi*'` returns 0 results. DPI-C C code that uses `svOpenArrayHandle` or `svGetArrElemPtr1` cannot be compiled. Standard DPI tests use `vpi_user.h` only.
- Probe: p79_dpi_open_array (VERIFIED-FAILS — gcc says svdpi.h not found).
- Location: vpi/ headers — svdpi.h missing entirely.
- Layer: build/install + DPI runtime.
- Complexity: deep (requires implementing the IEEE 1800-2017 §H.10 svdpi API).
- Blocks: any DPI library that processes SV arrays in C (cocotb-style adapters, DPI-driven stimulus).

# Important (works around but limits common patterns)

### G31 `process::self().status().name()` chained — enum method on function-return fails
- Symptom: `c.next().name()` fails with `error: No function named 'name' found in this context.` The same call without chain (`c2 = c.next(); c2.name();`) works.
- Probe: p32_typedef_enum_method (VERIFIED-FAILS chained), p32 with no chain (PASS).
- Location: elab_expr.cc method-call-on-function-call-result codepath.
- Layer: elab.
- Complexity: medium (need to keep type info through function-call result for method dispatch).
- Blocks: idiomatic chained method calls.

### G32 method-call chaining on class-handle returns: `c.with_v(42).with_v(100).v` fails
- Symptom: `c.with_v(42).with_v(100).v` produces `error: No function named 'with_v' found in this context.` Same call broken into temp variables works.
- Probe: p84_func_return_class (VERIFIED-FAILS chain, PASS no-chain).
- Location: same area as G31 — chained method/property dispatch on function-return class handles.
- Layer: elab.
- Complexity: medium.
- Blocks: builder-style class APIs.

### G34 `event arr[4]` = `sorry: event arrays are not supported`
- Symptom: parser explicitly rejects `event arrays`.
- Probe: p52_event_arr (VERIFIED-FAILS).
- Location: parse.y:10287.
- Layer: parser.
- Complexity: medium.
- Blocks: signaling patterns with N peers.

### G35 reverse() on unpacked array drops content
- Symptom: `int u[5] = '{1,2,3,4,5}; u.reverse();` shows u as empty `'{ , , , , }`. `q.reverse()` on queue shows `'{}`.
- Probe: p58_reverse_method (VERIFIED-FAILS).
- Location: elaborate.cc:5590 sorry: '`reverse()`' for non-queue, plus runtime emit.
- Layer: codegen+runtime.
- Complexity: small (queue version exists per Phase63b notes — extend to unpacked).
- Blocks: array manipulation idioms.

### G36 unpacked `int unp[5] = '{...}; unp.find()` returns OK but `unp.min()`, `.max()`, `.sort()` fail
- Symptom: `find()` works on unpacked array; `min()`, `max()`, `sort()` return 0/empty results. Internal warnings: `get_word(string) not implemented for vvp_darray_atomIiE`.
- Probe: p30_array_methods (VERIFIED-FAILS).
- Location: elab_expr.cc:8857-8911 (sorry block), plus vvp_darray_atomI dispatcher.
- Layer: elab + runtime.
- Complexity: medium.
- Blocks: standard reduction/sort idioms.

### G37 `assoc[string][]` (assoc-of-darray) foreach inner-loop var rejected
- Symptom: `C arr[string][];` with `foreach (arr[k][i])` reports `syntax error / Errors in foreach loop variables list.`
- Probe: p81_assoc_class_q (VERIFIED-FAILS).
- Location: parse.y foreach grammar.
- Layer: parser.
- Complexity: medium.
- Blocks: nested container patterns.

### G38 `string.putc(0, "J")` doesn't modify the string
- Symptom: `s = "Hello"; s.putc(0, "J");` leaves s as "Hello", expected "Jello".
- Probe: p34_string_methods (VERIFIED-FAILS).
- Location: vvp string method dispatcher.
- Layer: runtime.
- Complexity: small.
- Blocks: in-place string mutation idioms.

### G39 `dyn = new[N](old);` dynamic-array resize copy doesn't preserve values
- Symptom: `da = new[10](da);` returns size=10 but values printed as empty; runtime warning: `get_word(string) not implemented for vvp_darray_atomIiE`. Resize alone works; copy-resize loses payload.
- Probe: p35_dynarr_methods (PARTIAL — size correct, content not).
- Location: vvp_darray.cc copy-init path.
- Layer: runtime.
- Complexity: small-medium.
- Blocks: array-grow patterns.

### G40 unique() / unique_index() — works for queue, fails (sorry) for unpacked array
- Symptom: queue `q.unique_index()` works (probe p87 PASS). Unpacked-array form not directly probed but elab_expr.cc:8869,8875 show sorry.
- Probe: p87_unique_index (PASS for queue); REVERIFY for non-queue.
- Location: elab_expr.cc:8869,8875.
- Layer: elab.
- Complexity: small.
- Blocks: rare.

### G41 `static int instances[10];` (static class array) + `i*100` cast diagnostic confused
- **STATUS: FIXED (Phase 77)**
- Symptom: `instances[i] = i * 100;` from constructor reports `error: The expression '(i)*('sd100)' cannot be implicitly cast to the target type.` The mismatch is between idx-expr and array element type when static class array is in scope.
- Probe: p90_class_static_arr (VERIFIED-FAILS).
- Location: elab_sig.cc (3 sites in `elaborate_sig`, `seed_super_chain_properties_`, `seed_class_scope_properties_for_method_elab_`) — use `NetNet(scope, name, REG, ua->static_dimensions(), ua->element_type())` constructor so `unpacked_dims_` is populated. Belt-and-suspenders fallback in elab_lval.cc `elaborate_lval_var_` handles netuarray_t in `net_type_` with 0 `unpacked_dims_`.
- Fix: `tests/g41_static_class_array_test.sv` PASS (119 passed, 0 failed regression).
- Layer: elab.
- Complexity: small.
- Blocks: per-class instance trackers.

### G42 typed-default in assignment pattern `'{int: 0, default: 8'hFF}` syntax-rejected
- Symptom: `Malformed statement` at `'{int: 0, default: 8'hFF}`.
- Probe: p93_assignment_pattern (VERIFIED-FAILS for that line).
- Location: parse.y assignment_pattern rules.
- Layer: parser.
- Complexity: medium.
- Blocks: generic field-defaulting in struct patterns.

### G44 `unique case` — `Case unique/unique0 qualities are ignored`
- Symptom: explicit `vvp.tgt sorry: Case unique/unique0 qualities are ignored.` Runtime still warns on missing case via "value is unhandled for priority or unique case statement," so partial behavior exists.
- Probe: p18_unique_priority_case (VERIFIED-FAILS partially — case fires, quality dropped).
- Location: tgt-vvp/vvp_scope.c case translation.
- Layer: codegen.
- Complexity: small.
- Blocks: synthesis-flagged uniqueness checking.

### G45 `priority case` — falls to default even when matching pattern exists
- Symptom: `priority case (sel)` with `2'b1?` should match `sel=2'b10` but reaches default (`PROBE_FAIL_priority def`).
- Probe: p18_unique_priority_case (VERIFIED-FAILS).
- Location: tgt-vvp/vvp_scope.c case-quality dispatch.
- Layer: codegen.
- Complexity: small.
- Blocks: safety-critical priority-encoding patterns.

### G46 `union tagged` — `case (x) matches` w/ `tagged Inv`/`tagged Num .n` — partial
- Symptom: `tagged Num 42` constructor works (per I6); `case matches` extraction reports a syntax error for the void member (my probe used `void Inv` which the parser rejects).
- Probe: p22_tagged_match (VERIFIED-FAILS at struct/union member syntax).
- Location: parse.y union member rules + B7 case-matches still partial per phase63b notes.
- Layer: parser+elab.
- Complexity: medium.
- Blocks: ML-style pattern destructuring (uncommon in DV today).

### G47 "unresolved vpi name lookup" warning during UVM init
- Symptom: every UVM probe prints `unresolved vpi name lookup: v0x...; using null handle`. Cosmetic but indicates a code-path traversal sees a null vpi handle.
- Probe: any UVM probe (VERIFIED-FAILS).
- Location: vpi name resolution during UVM init.
- Layer: runtime.
- Complexity: medium (needs source trace).
- Blocks: nothing functionally; clutter.

### G48 `callf child did not end synchronously` warning during UVM message printing
- Symptom: `Warning: callf child did not end synchronously (caller=uvm_pkg::uvm_default_report_server.process_report_message.$unm_blk_1402 callee=uvm_pkg::uvm_default_report_server.execute_report_message); caller entering join wait`. Indicates nested call control-flow that vvp's call-frame logic doesn't model cleanly.
- Probe: any UVM probe with messages (VERIFIED-FAILS).
- Location: vvp/vthread.cc callf logic.
- Layer: runtime.
- Complexity: medium.
- Blocks: nothing functional (suppressed after first); diagnostic for stale-frame issues.

### G49 `class_property_t::get_object on unsupported property type` warning during randomize
- Symptom: every randomize call against a class with rand integer/bit fields warns `get_object on unsupported property type (class=T property=x type=sb32); returning null object`. Constraint solver works in many cases despite the warning.
- Probe: any randomize probe with class properties (VERIFIED-FAILS).
- Location: vvp/vvp_cobject get_object dispatcher missing integer/bit/enum types.
- Layer: runtime.
- Complexity: small.
- Blocks: spammy diagnostic; also indicates partial scoreboard-style introspection.

### G50 ifnone with edge-sensitive specify path = `sorry`
- Symptom: `ifnone (negedge a => b) = 10;` parser rejects with "Invalid simple path."
- Probe: p51_ifnone_edge (VERIFIED-FAILS).
- Location: parse.y:10332.
- Layer: parser.
- Complexity: small.
- Blocks: SDF-imported timing models with default paths.

### G51 `->>` intra-assignment event control = `sorry`
- Symptom: `x ->> @(e) value;` parser rejects.
- Probe: source-grounded; not directly probed (used `@(e) x = ...` workaround).
- Location: parse.y:11754,11760.
- Layer: parser.
- Complexity: small.
- Blocks: rare.

### G52 net delays in declarations = `sorry`
- Symptom: `wire #5 a;` declarative-side net delays rejected by parser.
- Probe: REVERIFY.
- Location: parse.y:9088,9098.
- Layer: parser.
- Complexity: small.
- Blocks: legacy timing declaration style.

### G53 trireg = `sorry`
- Symptom: parser rejects `trireg`.
- Probe: REVERIFY.
- Location: parse.y:9146.
- Layer: parser.
- Complexity: medium (trireg has charge-decay semantics).
- Blocks: rare.

### G54 config declarations = `sorry`
- Symptom: `config name; design...endconfig` rejected.
- Probe: REVERIFY.
- Location: parse.y:6316.
- Layer: parser.
- Complexity: medium.
- Blocks: lib/cell-mapping flows (uncommon in pure DV).

### G55 inout ports with unpacked dimensions = `sorry`
- Symptom: parser explicitly rejects, citing IEEE.
- Probe: REVERIFY.
- Location: parse.y:821.
- Layer: parser.
- Complexity: medium.
- Blocks: bidirectional bus-array ports (uncommon).

### G56 array slices in continuous assigns = `sorry`
- Symptom: `assign dst = src[1:3];` for unpacked array slice, or `assign uarr_full = uarr_other` of unpacked: `array slices not yet ...`. Procedural assign of unpacked also limited.
- Probe: p53_arr_slice (VERIFIED-FAILS for procedural unpacked-array assign — type-mismatch netvector vs netuarray).
- Location: elab_net.cc:1184; elab_lval.cc:546 mention assignments to part selects of nets.
- Layer: elab.
- Complexity: medium.
- Blocks: bus-slice routing.

### G57 `solve…before` interaction with implication: probe p17 — solve worked but b ended random
- Already noted in G11; same root cause as G15 (implication).

### G58 `wait fork; disable fork` works — but `process` introspection limited to status enum (G07)
- Already noted.

### G59 `global clocking` block syntax error
- Symptom: `global clocking cb @(posedge clk); endclocking` rejected as `Invalid module item / syntax error`.
- Probe: p68_global_clocking (VERIFIED-FAILS).
- Location: parse.y — `global clocking` keyword combo not in grammar.
- Layer: parser.
- Complexity: medium (changes the default clocking-event-resolution rules).
- Blocks: cleaner DV testbench style.

### G60 default arguments + class methods — works for classes (PASS), but elab_sig.cc:1352 still emits `sorry: Default arguments` in some context
- Symptom: probe passes for class-method default args (G54 negative); the sorry is for non-class-method paths (e.g. typed-non-class subroutine ports).
- Probe: p54_default_args (PASS for class methods); REVERIFY for the sorry path.
- Location: elab_sig.cc:1352.
- Layer: elab.
- Complexity: medium.
- Blocks: rare.

### G61 `subroutine_port with` (elab_sig.cc:1385 sorry: "Subroutine ports with…")
- Symptom: source-grounded; some DPI signature shapes hit this.
- Probe: REVERIFY.
- Location: elab_sig.cc:1385.
- Layer: elab.
- Complexity: medium.
- Blocks: extended DPI types.

### G62 program-block clocking inside module — same root as G02
- Already noted G02.

### G65 `uvm_phase pre_main / main` task hooks — phase task body invoked twice
- Symptom: `pre_main_phase` and `main_phase` print `PROBE_OK_premain` twice each in p61. Indicates the phase scheduler invokes the task body twice (possibly via parent class fallthrough or schedule re-entry).
- Probe: p61_uvm_objection_chain (VERIFIED-FAILS — duplicate calls).
- Location: uvm_phase.svh in iverilog's UVM tree, or vvp scheduling of phase fork.
- Layer: runtime + UVM.
- Complexity: medium.
- Blocks: subtle (objection counts, log dedup).

# Confirmed-working baselines (not gaps; recorded for diff against future regressions)

These were probed and pass cleanly. Keep this list so a regression can be detected easily.

- chandle null + equality: p09_chandle, p31_dpi_chandle
- mailbox#(int) try_get/try_peek: p10_mailbox
- semaphore non-1-key get/put: p11_semaphore
- parameterized class extends parameterized class (2 levels): p13_paramext_paramcls
- super.new 4-level inheritance chain: p14_super_chain
- forward-typedef'd cyclic class refs: p75_typedef_fwdref
- default-args constructor inherited: p76_class_extends_new_args
- pure virtual / abstract class: p85_pure_virtual
- class const member: p41_class_const
- static class methods/properties: p40_class_static_methods
- parameterized class with method on parameterized type: p59_param_method_param
- force/release on register: p80_force_release
- specparam + simple path delay: p69_specparam_path
- string concat + replicate: p70_string_replace
- typed-default args on class methods: p54_default_args
- enum methods (next/prev/first/last/num) without chaining: p32 (after fix)
- assoc array of class objects + foreach: p97_assoc_obj_iterate
- queue.unique_index(): p87_unique_index
- mailbox basic (Phase 53 era): p10
- timeunit/timeprecision/1step: NOT probed cleanly — REVERIFY (p38 hit a syntax error on `timeunit` declaration in module body)
- final blocks: p06_final
- $strobe / $monitor / $timeformat / $printtimescale: p07_sysfuncs
- foreach over single-dim assoc: p36_assoc_methods, p15 (single dim only)
- streaming RHS `{<<8{src}}`: p74_concat_expr
- handle assignment / shared state: p94_class_assign
- TLM analysis port + custom transaction: p27_uvm_tlm_custom (after fix)
- factory `T::type_id::create + set_type_override`: p96_uvm_obj_factory
- uvm_objection raise/drop with finite delay: p50_uvm_objection
- UVM phase: build/main/run end-to-end with reg_block.lock_model and reg.set/get: p26_uvm_reg_full
- extern function/task in package: p20_extern_pkg
- interface task/function called via virtual interface: p42_iface_method
- parameterized interface: p86_iface_param
- packed slice on LHS / indexed slice LHS: p63_packed_slice_lhs
- 2D unpacked array foreach: p46_array_2d_unp
- real / shortreal / realtime sysfunc: p47_realtime
- disable fork; wait fork; join_any: p48_disable_fork
- parameterized class type-parameter specialization: p49_paramcls_specialization
- class handle as assoc-array key: p64_class_hand_assoc
- clocking inside interface (only allowed location): p66_clocking_iface
- string foreach over chars: p88_string_iter
- DPI export decl (no body verified): p89_dpi_export
- extern constraint definition: p92_extern_constraint
- inside { range, value, queue } mixed: p19_inside_mixed

# Source-grounded sorry sites I did NOT probe (REVERIFY for completeness)

These are listed for traceability — not separate gap entries, but they're known limitations the source acknowledges:

- elaborate.cc:584,594,603,656,719,729,738 — variant `sorry` clusters in elaborate.cc that I didn't isolate. Many likely overlap with G31/G32 method-on-paramcls dispatch.
- elab_lval.cc:1269,1278,1286,1331,1516,1524 — lvalue shapes (likely netarray slice patterns).
- elab_lval.cc:1772 — assignments to part selects of nets.
- vvp/vpi_priv.cc:743,876,947,982,1029 — VPI value-format unimplemented for various format codes.
- vvp/vpi_darray.cc:137,200,225 — VPI darray queries unimplemented.
- vvp/array.cc:240 — VPI array format.
- vvp/vpi_priv.cc:1691,1725,1733 — `vpi_handle_multi` partial.
- elab_expr.cc:574,588 — string-method partial implementations.
- elab_expr.cc:6927 — methods of parameters of certain types.
- elab_expr.cc:8421 — likely an array-method dispatch fallback.
- elab_expr.cc:9013 — likely string-method specialization.
- elab_expr.cc:12027 — likely UVM-pattern catchall.

# Compile-progress fallback hot spots (45 sites)

These are paths where iverilog deliberately emits a permissive code-shape rather than a hard error. Each is a potential silent miscompile in the unhandled-shape edge. Categorized by file:

- **netmisc.cc:828, 933, 949, 1094, 1120**: parameterized/UVM-heavy paths in expression tree-walking — most relate to type-parameter resolution that returned null. Patches preferred for parameterized classes likely already covered by Phase 50/53 work.
- **elab_expr.cc:879, 883, 1124, 1132, 1333, 3140, 5338, 5387, 5757, 6085, 6264, 6357, 6371, 7507, 8294, 8305, 8318, 8326, 9209, 11827, 11922**: 21 sites; most cluster around enum/typedef/class-member dispatch. Probes G22, G31, G32, G47, G49 hit some of these.
- **net_func_eval.cc:261, 365, 1168, 1179, 1303**: constant-function evaluation fallbacks. Risk: silent compile-time-evaluation mistakes that affect parameter values.
- **net_link.cc:455**: SystemVerilog static class member — likely related to G41.
- **elab_sig.cc:1088**: hidden-constructor fallback.
- **elab_lval.cc:1393**: tolerate unknown lvalue members — could mask silent assignment-misroutes.
- **elaborate.cc:4437, 4523, 4906, 7740**: elaborate.cc fallbacks; need source diff to attribute.
- **vvp/vthread.cc:1482, 12603, 13263, 13627, 13683**: runtime fallbacks. Risk: silent runtime no-ops.
- **vvp/vvp_darray.cc:1033**: darray runtime fallback.
- **net_expr.cc:462**: parameterized wrapper expression fallback.

# Probe inventory

99 probe `.sv` files in `/tmp/audit_2026_05/p*.sv` with `.log` companion. Run via `/tmp/audit_2026_05/probe.sh` (UVM include) or `probe_nouvm.sh`.

# Notes on Phase-63b stale items

- I2 (uvm_default_table_printer) closed by 922c2181e + a93e3c8cc — confirmed not regressed in p72 print() output.
- I7 queue-of-class get_word warning (5eff7c48f silenced it) still fires under different classes. See G25 / G36.
