`include "uvm_macros.svh"
import uvm_pkg::*;

class my_item3 extends uvm_sequence_item;
  rand bit [7:0] data;
  `uvm_object_utils(my_item3)
  function new(string name = "my_item3");
    super.new(name);
  endfunction
endclass

class no_rand_test extends uvm_test;
  `uvm_component_utils(no_rand_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    my_item3 item;
    phase.raise_objection(this);
    item = my_item3::type_id::create("item");
    $display("item created, data=%0d", item.data);
    $display("No-rand test PASSED!");
    phase.drop_objection(this);
  endtask
endclass

module top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  initial begin
    run_test("no_rand_test");
  end
endmodule
