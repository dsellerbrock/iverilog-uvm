// Phase 63b / B3: silence "Enable of unknown task `first.copy`/`second.copy`"
// warnings emitted by UVM uvm_pair#(T1=int, T2=int).do_copy when T
// defaults to int.  The body calls `first.copy(rhs_.first)` etc.,
// which doesn't exist on int.  Same dead-spec pattern as B2 but for
// task enables instead of function calls.
//
// Pre-fix:
//   uvm_pair.svh:121: warning: Enable of unknown task ``first.copy''
//   uvm_pair.svh:122: warning: Enable of unknown task ``second.copy''
`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

class my_obj extends uvm_object;
  `uvm_object_utils(my_obj)
  function new(string name = "my_obj"); super.new(name); endfunction
endclass

module top;
  initial begin
    my_obj o = my_obj::type_id::create("o");
    if (o == null) $fatal(1, "FAIL: factory create returned null");
    $display("PASS: UVM compile clean of uvm_pair.*.copy warnings");
    $finish;
  end
endmodule
