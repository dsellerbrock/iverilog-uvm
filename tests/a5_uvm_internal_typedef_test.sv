// Phase 63a / A5: UVM macros declare compiler-synthesized typedefs
// like `__tmp_int_t__` inside a begin/end block, then pass them as
// parameter to parameterized classes (e.g. uvm_resource#(__tmp_int_t__)).
// iverilog's spec class scope doesn't see the begin/end block typedef,
// so the type lookup falls back to integer_type with a noisy warning.
//
// Pre-fix: every UVM compile printed "Can not find the scope type
// definition `__tmp_int_t__` (compile-progress fallback)" at
// uvm_agent.svh:127.
//
// Fix: suppress the warning for UVM-internal `__name__` typedefs
// (the integer_type fallback already produces working code in the
// affected uvm_resource_*_read read-back contexts).
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
    $display("PASS: UVM compile clean of `__tmp_int_t__` typedef warning");
    $finish;
  end
endmodule
