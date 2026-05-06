// G22 regression test: uvm_factory::get().create_object_by_name(...)
// Verifies that a chained method call on a singleton-returning static
// function result elaborates and dispatches correctly.
`include "uvm_macros.svh"
import uvm_pkg::*;

class g22_obj extends uvm_object;
  `uvm_object_utils(g22_obj)
  function new(string name = "g22_obj"); super.new(name); endfunction
endclass

module top;
  initial begin
    uvm_object obj;

    // Chained form: uvm_factory::get().create_object_by_name(...)
    obj = uvm_factory::get().create_object_by_name("g22_obj", "", "inst");
    if (obj == null) begin
      $display("FAIL: uvm_factory::get().create_object_by_name returned null");
      $finish;
    end
    if (obj.get_type_name() != "g22_obj") begin
      $display("FAIL: wrong type_name '%s'", obj.get_type_name());
      $finish;
    end
    $display("PASS");
    $finish;
  end
endmodule
