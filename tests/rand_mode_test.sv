// rand_mode() test: obj.rand_mode(0) disables randomization; value stays fixed.
`include "uvm_macros.svh"
import uvm_pkg::*;

class rand_item extends uvm_object;
  `uvm_object_utils(rand_item)

  rand int unsigned data;

  function new(string name = "rand_item");
    super.new(name);
    data = 42;
  endfunction
endclass

class rand_mode_test extends uvm_test;
  `uvm_component_utils(rand_mode_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    rand_item item;
    int prev;
    phase.raise_objection(this);

    item = rand_item::type_id::create("item");

    // With rand_mode enabled (default), data should be randomized.
    item.rand_mode(1);
    item.randomize();
    `uvm_info("TEST", $sformatf("rand_mode=1: data=%0d", item.data), UVM_NONE)
    if (item.data === 42)
      `uvm_warning("TEST", "data still 42 after randomize (unlikely but possible)")

    // Disable rand_mode — data must not change across randomize() calls.
    item.rand_mode(0);
    prev = item.data;
    item.randomize();
    `uvm_info("TEST", $sformatf("rand_mode=0: prev=%0d after_rand=%0d", prev, item.data), UVM_NONE)
    if (item.data !== prev) begin
      `uvm_error("TEST", "rand_mode(0) failed: data changed after randomize()")
    end else begin
      `uvm_info("TEST", "rand_mode(0) PASSED: data unchanged", UVM_NONE)
    end

    // Re-enable and randomize again.
    item.rand_mode(1);
    item.randomize();
    `uvm_info("TEST", $sformatf("rand_mode=1 again: data=%0d", item.data), UVM_NONE)

    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("rand_mode_test");
endmodule
