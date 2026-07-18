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

The generated vvp for both calls is structurally identical (alloc /
arg stores / callf / copy-out load+store / free); the difference is the
nested `%alloc`/`%callf`/`%free` of the inner method's scope sitting
between the outer `%alloc` and the argument stores, which perturbs the
automatic-frame read/write context handoff in vvp/vthread.cc
(of_ALLOC's staged rd-context logic and of_FREE's rd handoff are the
suspect area). Hoisting the method-call arguments into temporaries
before the call makes the ref copy-out work.

Known consequence: the UVM RAL front-door is a silent no-op. In
`uvm_reg_map::do_bus_access`,
`void'(get_physical_addresses_to_map(m_regs_info[r].offset, 0,
r.get_n_bytes(), adr, null, byte_offset))` loses the `adr` write-back,
so zero bus accesses are generated while the operation completes with
UVM_IS_OK — `uvm_reg::write/read` "succeed" without touching the bus
(reads return 0). This is a textbook silent miscompile and blocks
tests/wip/m7_reg_frontdoor_stress_test.sv, which is quarantined outside
the sweep glob until the fix lands.

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
