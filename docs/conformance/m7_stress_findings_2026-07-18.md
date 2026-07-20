# M7 stress findings — 2026-07-18

The Phase-1 M7 stress work (register-model + objections suites) found two
compiler/runtime defects. Both are reduced to minimal repros here so the
follow-up work does not depend on session state.

## Finding 1: class event properties are shared per-class (not per-instance)

A non-static `event` property of a class elaborates to a single `.event`
functor in the class scope, so every instance shares it: triggering
`b.ev` wakes a waiter on `a.ev`.

```systemverilog
class evbox;
  event ev;
endclass
module evclass_t;
  evbox a, b;
  initial begin
    a = new; b = new;
    fork
      begin @(a.ev); $display("BAD: waiter on a woke (only b triggered)"); end
      begin @(b.ev); $display("OK: waiter on b woke"); end
    join_none
    #5 ->b.ev;
    #5 $finish(0);
  end
endmodule
// Current output includes the BAD line. Correct output has only OK.
```

Status: made LOUD (elab_scope.cc emits a warning when a class declares
event properties). A real fix needs per-instance event storage in class
objects plus dynamic wait/trigger opcodes in vvp — Phase-2-sized.

Known consequence: the UVM 2020.3.1 phase hopper's `run_phases()` waits
for `UVM_ALL_DROPPED` on its own `uvm_objection`, whose event members
(`uvm_objection_events` class: `raised`/`dropped`/`all_dropped`) are
cross-woken by *other* objection instances. The hopper's waiter wakes as
soon as the run phase's own objection clears, while the hopper objection
total is still nonzero, so `run_test` proceeds straight to `$finish`:
**the post-run function phases (extract / check / report / final) never
execute**. UVM tests must do final checks at the end of `run_phase` (see
tests/m7_objection_stress_test.sv) until this is fixed.

## Finding 2: `ref` dyn-array copy-out lost when another argument contains a method call

When a function call passes a dynamic array by `ref` AND another
argument expression contains a method call, the ref write-back is
silently dropped (the callee sees and fills the array; the caller's
variable stays untouched). Deterministic on the current build.

```systemverilog
typedef bit [63:0] addr_t;
class info_t;  addr_t offset; endclass
class regc;    function int unsigned get_n_bytes(); return 4; endfunction endclass

class mapper;
  info_t m_regs_info [regc];
  function int gpa(addr_t base, addr_t off, int unsigned n,
                   ref addr_t addr[], input mapper parent,
                   ref int unsigned skip);
    addr = new[1];
    addr[0] = base + n;
    return 0;
  endfunction
  function void drive(regc r);
    addr_t adr[];
    int unsigned byte_offset;
    void'(gpa(64'h4, 0, r.get_n_bytes(), adr, null, byte_offset));
    $display("method-arg: size=%0d", adr.size());  // BUG: prints 0, want 1
    adr.delete();
    void'(gpa(m_regs_info[r].offset, 0, 4, adr, null, byte_offset));
    $display("assoc-arg:  size=%0d", adr.size());  // OK: prints 1
  endfunction
endclass

module refda_args_t;
  initial begin
    mapper m; regc r; info_t inf;
    m = new; r = new; inf = new;
    inf.offset = 8;
    m.m_regs_info[r] = inf;
    m.drive(r);
    $finish(0);
  end
endmodule
```

**STATUS: FIXED.** Root cause: the nested `%alloc`/`%callf`/`%free` of
the inner method's scope sits between the outer call's `%alloc` and its
argument stores. of_FREE's read-context handoff unconditionally handed
reads to the live write head — the STAGED, not-yet-called outer frame —
so the read and write heads became equal; do_join's `wt != rd` staging
test then skipped the callee-frame pop-push at the outer call's return,
and the ref/output copy-back stored through the callee frame instead of
the caller frame. Fix (vvp/vthread.cc of_FREE): only run the handoff
ladder when the post-removal read head is dead — removing the freed
frame from the read chain already restores the caller frame naturally.
Regression: tests/m7_ref_arg_copyout_test.sv (all four argument shapes).

Original consequence: the UVM RAL front-door was a silent no-op. In
`uvm_reg_map::do_bus_access`,
`void'(get_physical_addresses_to_map(m_regs_info[r].offset, 0,
r.get_n_bytes(), adr, null, byte_offset))` lost the `adr` write-back,
so zero bus accesses were generated while the operation completed with
UVM_IS_OK. With the fix, the address path works (transactions reach the
bus driver at the right times with the right payloads); the front-door
test is still blocked by finding 4 below.

## Repro / verification commands

```
iverilog -g2012 -o /tmp/ev.vvp evclass.sv && vvp /tmp/ev.vvp
iverilog -g2012 -o /tmp/ra.vvp refda_args.sv && vvp /tmp/ra.vvp
```

## Finding 3: stored `$time` in $unit class methods scales to 0

A `` `timescale `` directive is not applied to class declarations in
the compilation-unit scope, so their methods evaluate `$time` (an
integer number of the SCOPE's time units) against the simulator default
unit (1s): at 7ns, `$realtime` returns 7e-9 and `$time` rounds to 0.

```systemverilog
`timescale 1ns/1ns
class box;
  time last = 0;
  real rt = 0;
  task bump(); #7; last = $time; rt = $realtime; endtask
endclass
module timeprop_t;
  initial begin
    box b; b = new;
    fork b.bump(); join_none
    #10 $display("last=%0d rt=%0g", b.last, b.rt);  // last=0 rt=7e-09
    $finish(0);
  end
endmodule
```

Commercial simulators apply the active `` `timescale `` to subsequent
$unit declarations, so class methods there see ns units. Divergence to
fix with the M13/M14 conformance tails. (Inside packages with their own
timescale — e.g. UVM classes — units resolve as expected; a direct
`$time` in a `$display` argument also formats correctly via %t. The
observable failure is a stored `$time` compared numerically, as the
first version of tests/m7_objection_stress_test.sv did.)


## Finding 4: parameterized-class virtual dispatch resolves into the wrong specialization

With finding 2 fixed, the RAL front-door advances to the sequencer
handoff and exposes the next layer: the driver's
`seq_item_port.get_next_item(req)` returns null (all-zero property
reads under null leniency) even though the sequence side put a valid
item in the fifo. Instrumentation of the UVM chain shows the port
dispatches to the imp, the imp's forward "succeeds" — but
`uvm_sequencer#(m7_bus_txn)::get_next_item` never executes (a
different specialization's method ran instead), and the port-level
output-argument copy-back drops the returned handle.

Reduced repro (both defects in ~50 lines; note the shapes are adjacent
to but not identical with the UVM failure — in UVM the imp call
resolves but to the wrong specialization):

```systemverilog
class item;
  int unsigned tag;
  function new(int unsigned t = 0); tag = t; endfunction
endclass

class sqr_if_base #(type REQ = int);
  virtual task get_next(output REQ t);
    $display("  STUB hit (wrong)");
  endtask
endclass

class sequencer #(type REQ = int) extends sqr_if_base #(REQ);
  REQ stash;
  virtual task get_next(output REQ t);
    #1; t = stash;
  endtask
endclass

class imp_c #(type REQ = int, type IMP = int) extends sqr_if_base #(REQ);
  IMP m_imp;
  virtual task get_next(output REQ t);
    m_imp.get_next(t);   // BUG (a): "Enable of unknown task" fallback:
  endtask                // a call through a bare type-parameter-typed
endclass                 // member does not resolve.

class port_c #(type REQ = int);
  sqr_if_base #(REQ) m_if;
  task get_next(output REQ t);
    m_if.get_next(t);    // BUG (b): dispatch hits the base STUB, not
  endtask                // the imp_c override.
endclass
```

This is M1B typing-fidelity territory (specialization-aware method
tables), one of the closure plan's two big rocks — not a bounded
runtime fix. tests/wip/m7_reg_frontdoor_stress_test.sv stays
quarantined until it lands.

### Update (2026-07-20): BOTH halves FIXED — test un-quarantined

Finding 4 was really two independent defects; both are now fixed and
`m7_reg_frontdoor_stress_test.sv` has moved out of `tests/wip/` into the
standard sweep, passing checks=4 writes=4 reads=4.

The first — a parameterized-class VARIABLE/HANDLE/PROPERTY declaration
not specializing — is fixed:

  * `pform.cc` (`pform_make_modgates`): a `Class #(args) name;`
    declaration reaches the no-port module-instantiation shape and is
    reinterpreted as a variable declaration. The `#(args)` overrides
    were dropped there, so the GENERIC netclass (every type parameter
    at its default) was bound and a type-parameter-typed member kept
    its default type (int), landing a method call in the "Enable of
    unknown task" no-op / a `pop_prop_val` assertion. The overrides are
    now threaded onto the reinterpreted typeref, so the handle
    specializes exactly as `extends Class#(args)` already did.
  * `elab_scope.cc` (`seed_specialized_method_bodies_`): handle/variable
    specialization uses `fully_elaborate=false` (seed only), which
    seeded only a whitelist of housekeeping methods. A user VIRTUAL
    override was therefore never elaborated, so its `TD_` label was
    never emitted and runtime virtual dispatch through a parameterized
    base handle fell through to the base stub. Every virtual method is
    now seeded (a virtual override is always a dispatch target).

Regression: `tests/m1b_typeparam_member_call_test.sv` (specialized member
call + parameterized virtual dispatch through a base handle + a member
typed by a type-parameter inside an extending subclass). All four gates
stay green (UVM 200/0).

The SECOND defect — a distinct, PRE-EXISTING RUNTIME bug that is not
parameterized-specific — is also fixed:

  * `vvp/vthread.cc` (`do_join`): a virtual task with an `output`
    argument dispatched via `%fork/v` runs its override in a separate
    dispatch context that is NOT on the caller's write stack. The only
    frame stacked there is the `%alloc`'d call-site (base-scope) frame.
    do_join's pop-push looked for the OVERRIDE scope's frame to pop,
    found nothing, and left the base frame at the write head — so the
    enclosing task's own `output` store landed in the base frame instead
    of its own, silently dropping the returned handle (caller saw null).
    The pop-push now targets the base (call-site) scope for a
    dynamically dispatched child, exactly as the non-virtual call path
    does. This reproduced with plain (non-templated) classes too.

Regression: `tests/m1b_virtual_output_copyback_test.sv` (plain and
parameterized shapes) plus the un-quarantined
`tests/m7_reg_frontdoor_stress_test.sv`. All four gates green (UVM 200/0,
ivtest clean, SVA 32/0, build).

(One adjacent limitation is still open and independent of the above:
member access on an `output` formal typed by a type-parameter —
"Variable t does not have a field named ..." — fails even on the
fully-elaborated path. It does not block the RAL front door, which passes
the returned handle through without dereferencing an output-typed
type-parameter formal.)


## Finding 5: dup_expr of a function call loses its upgraded type — FIXED

Lowerings that DUPLICATE a function-call expression (`inside`, dist,
range compares) rebuilt the call through its constructor, which
derives the type from the result signal and loses elaboration's type
upgrade. A string-returning call in `f() inside {"a","b"}` compiled
to a vec4 compare against a string-stack result: vec4-stack
underflow, garbage comparison, always false.

Fix: NetEUFunc::dup_expr copies the original expression's current
net type onto the clone (dup_expr.cc). Regression:
tests/inside_string_func_test.sv.

Consequence repaired: `uvm_reg`'s access check
(`get_rights(...) inside {"RW","WO"}`) always failed, so EVERY
backdoor register operation returned UVM_NOT_OK. This is what had
been mis-diagnosed as "reg_basic_test needs DPI HDL access" — a
USER-DEFINED uvm_reg_backdoor never needed DPI. reg_basic_test is
now un-skipped and passes; the skip-reason correction is recorded in
.github/uvm_test.sh. (The uvm_hdl_* DPI backdoor is separate future
work: DPI exports + UVM's DPI C library, the planned M10C.)

## Finding 6: property access through an indexed aggregate element mis-compiles (3 shapes)

Found by the register-model semantics stress: `uvm_reg::get_address`
returns 0 because Xinit_address_mapX's cache store
`m_regs_info[rg].addr = addrs` silently vanishes. Reduced, three
distinct defects:

```systemverilog
class keyc; endclass
class info_t;  int unsigned n;  bit [63:0] addr[]; endclass

info_t by_key [keyc];   keyc k = new;   by_key[k] = new;
info_t da[] = new[1];   da[0] = new;
bit [63:0] a[] = new[1];

// (a) ASSOC-indexed base, ANY property: the elaboration binds the
//     WRONG OBJECT — `by_key[k].n = 42` compiles to a property store
//     into `k` itself (the key variable), and the read side does the
//     same, so both directions silently target garbage.
by_key[k].n = 42;          // reads back 0
by_key[k].addr = a;        // reads back empty

// (b) darray/queue-indexed base, OBJECT-typed property store: the
//     assignment compiles to a property LOAD opcode (%prop/obj
//     instead of %store/prop/obj) — a silent no-op.
da[0].addr = a;            // reads back empty

// (c) darray/queue-indexed base, scalar property: works.
da[0].n = 42;              // OK
```

UVM survives in most places because its code copies the element
handle to a local first (`info = m_regs_info[rg]; info.addr = ...`),
which works — but Xinit_address_mapX assigns through the indexed
handle directly, so the register address cache is never written and
`get_address`/`m_regs_by_offset` (and therefore uvm_reg_predictor
lookups) see nothing. tests/m7_reg_model_semantics_test.sv documents
the trimmed get_address checks to restore when this lands. Fix scope:
elab_lval/elab_expr must fetch the aggregate ELEMENT as the object
expression before applying property access (shape a), and the
assignment codegen must emit the store-property opcode for
object-typed properties through indexed bases (shape b). This joins
the M1B/M4-family typing work.
