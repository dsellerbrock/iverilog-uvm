// G23 regression: `uvm_register_cb(T, cb_type) macro.
// Verifies that a class with uvm_register_cb elaborates without errors.
`include "uvm_macros.svh"
import uvm_pkg::*;

class g23_trans extends uvm_sequence_item;
  `uvm_object_utils(g23_trans)
  int val;
  function new(string name = "g23_trans"); super.new(name); endfunction
endclass

class g23_cb extends uvm_callback;
  `uvm_object_utils(g23_cb)
  function new(string name = "g23_cb"); super.new(name); endfunction
  virtual task pre_drive(g23_trans t); endtask
endclass

class g23_drv extends uvm_driver#(g23_trans);
  `uvm_component_utils(g23_drv)
  `uvm_register_cb(g23_drv, g23_cb)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

module top;
  initial begin
    $display("PASS");
    $finish;
  end
endmodule
