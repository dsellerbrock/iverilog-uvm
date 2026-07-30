// Regression for the G65/ICE family: a runtime-schedule task-phase hook
// (main_phase) overridden WITHOUT the `virtual` keyword must execute
// exactly once per component, and components that do NOT override it
// (uvm_root, the test) must not execute the override at all. Pre-fix,
// the sole-override static devirtualization plus the missing
// implicit-virtual flag sent every component through the override with
// a wrong-class `this`; the first property access aborted vvp
// (vvp_vector4_t::add width assert).
`include "uvm_macros.svh"
import uvm_pkg::*;

class counting_comp extends uvm_component;
  `uvm_component_utils(counting_comp)
  int run_count = 0;
  int main_count = 0;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  // Deliberately no `virtual` keyword: implicit per IEEE 1800-2017 8.20.
  task run_phase(uvm_phase phase);
    run_count++;
  endtask
  task main_phase(uvm_phase phase);
    main_count++;
  endtask
endclass

class phase_hook_count_test extends uvm_test;
  `uvm_component_utils(phase_hook_count_test)
  counting_comp c1, c2;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    c1 = counting_comp::type_id::create("c1", this);
    c2 = counting_comp::type_id::create("c2", this);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    #100;
    phase.drop_objection(this);
  endtask
  function void report_phase(uvm_phase phase);
    if (c1.run_count == 1 && c2.run_count == 1 &&
        c1.main_count == 1 && c2.main_count == 1)
      `uvm_info("RESULT", "PASS: all task phases ran exactly once", UVM_NONE)
    else
      `uvm_error("RESULT", $sformatf(
        "FAIL: c1.run=%0d c2.run=%0d c1.main=%0d c2.main=%0d (each must be 1)",
        c1.run_count, c2.run_count, c1.main_count, c2.main_count))
  endfunction
endclass

module top;
  initial run_test("phase_hook_count_test");
endmodule
