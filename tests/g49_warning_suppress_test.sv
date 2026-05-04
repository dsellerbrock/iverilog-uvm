// G49: no spurious get_object warning for scalar rand properties
// G47: no spurious unresolved vpi name lookup warning
// G48: no spurious callf child async warning
`include "uvm_macros.svh"
import uvm_pkg::*;

class my_item extends uvm_object;
  `uvm_object_utils(my_item)
  rand int value;
  rand bit [7:0] data;
  constraint c { value inside {[1:100]}; }
  function new(string name = "my_item"); super.new(name); endfunction
endclass

class my_test extends uvm_test;
  `uvm_component_utils(my_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    my_item item = my_item::type_id::create("item");
    phase.raise_objection(this);
    void'(item.randomize());
    if (item.value >= 1 && item.value <= 100)
      `uvm_info("TEST", "G49_PASS: rand int constrained correctly", UVM_LOW)
    else
      `uvm_error("TEST", $sformatf("FAIL: value=%0d not in [1:100]", item.value))
    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("my_test");
endmodule
