// Regression: @(class_member) must react to a real value change of the object,
// not fire on every write (incl. same-value writes) to the object.
//
// iverilog compiles @(obj.member) as an anyedge on the whole object handle, and
// %store/prop unconditionally notified that handle -- so a same-value write to
// ANY property woke ALL @(member) waiters on the object.  Two forever-loops
// each waiting on @(a distinct member) of the same object then cross-fired and
// spun forever in zero time, starving the time wheel.  This is the OpenTitan
// aon_timer_scoreboard hang: compute_num_clks WKUP_thread (@(wkup_num_update_due))
// and WDOG_thread (@(wdog_num_update_due)) -- both members of the scoreboard --
// ping-ponged, so simulation time never advanced and reset never applied.
//
// Fixed by notifying @(obj.property) waiters only on an ACTUAL value change
// (vector and object property writes), matching standard @(var) edge semantics.
//
// The test itself is the check: if the two waits cross-fire, the loops spin in
// zero time and the `#100ns` below is starved (time never advances) -> harness
// timeout / no PASS.  When correct, the writes are same-value, no spurious wake
// occurs, time advances, and the test reports PASS.
`include "uvm_macros.svh"
import uvm_pkg::*;

class spinner extends uvm_object;
  `uvm_object_utils(spinner)
  bit a;
  bit b;
  function new(string name="spinner"); super.new(name); endfunction
  // Each loop writes only its OWN member, with the same value it already holds
  // in steady state -- exactly the aon_timer WKUP/WDOG pattern.
  task automatic runA(); forever begin @(a); a = 1'b0; end endtask
  task automatic runB(); forever begin @(b); b = 1'b0; end endtask
endclass

class my_test extends uvm_test;
  `uvm_component_utils(my_test)
  spinner s;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    s = spinner::type_id::create("s");
    fork s.runA(); s.runB(); join_none
    s.a = 1'b1;   // kick A once (0->1 change); B must NOT cross-fire-spin
    #100ns;       // starved forever if @(a)/@(b) cross-fire in zero time
    `uvm_info("TEST", "EVENT_SPECIFICITY_PASS (time advanced, no cross-fire spin)", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("my_test");
endmodule
