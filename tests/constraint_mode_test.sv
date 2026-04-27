// Test: constraint_mode(0/1) per-named-constraint enable/disable
// constraint_mode(0) disables a named constraint so randomize() ignores it;
// constraint_mode(1) re-enables it.
`include "uvm_macros.svh"
import uvm_pkg::*;

class bounded_item extends uvm_sequence_item;
  `uvm_object_utils(bounded_item)
  rand int unsigned data;
  constraint valid_range { data inside {[0:99]}; }

  function new(string name = "bounded_item");
    super.new(name);
  endfunction
endclass

class constraint_mode_test extends uvm_test;
  `uvm_component_utils(constraint_mode_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    bounded_item item;
    int pass_count;
    int out_of_range_count;
    phase.raise_objection(this);

    item = bounded_item::type_id::create("item");

    // --- Test 1: constraint enabled (default) ---
    pass_count = 0;
    for (int i = 0; i < 20; i++) begin
      void'(item.randomize());
      if (item.data < 100) pass_count++;
    end
    if (pass_count == 20)
      `uvm_info("CM_TEST", "PASS: constraint active - all 20 values in [0:99]", UVM_NONE)
    else
      `uvm_error("CM_TEST", $sformatf("FAIL: constraint active - only %0d/20 in range", pass_count))

    // --- Test 2: disable constraint, expect out-of-range values ---
    item.valid_range.constraint_mode(0);
    out_of_range_count = 0;
    for (int i = 0; i < 50; i++) begin
      void'(item.randomize());
      if (item.data >= 100) out_of_range_count++;
    end
    if (out_of_range_count > 0)
      `uvm_info("CM_TEST", $sformatf("PASS: constraint disabled - %0d/50 values >= 100 (out of range)", out_of_range_count), UVM_NONE)
    else
      `uvm_error("CM_TEST", "FAIL: constraint disabled - all 50 values still in range (constraint not disabled?)")

    // --- Test 3: re-enable constraint ---
    item.valid_range.constraint_mode(1);
    pass_count = 0;
    for (int i = 0; i < 20; i++) begin
      void'(item.randomize());
      if (item.data < 100) pass_count++;
    end
    if (pass_count == 20)
      `uvm_info("CM_TEST", "PASS: constraint re-enabled - all 20 values back in [0:99]", UVM_NONE)
    else
      `uvm_error("CM_TEST", $sformatf("FAIL: constraint re-enabled - only %0d/20 in range", pass_count))

    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("constraint_mode_test");
endmodule
