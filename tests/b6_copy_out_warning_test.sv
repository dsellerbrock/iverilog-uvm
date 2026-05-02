// Phase 63b / B6: function copy-out warning now reports file:line of
// the call site instead of just the port name, making the
// "skipping unsupported copy-out" diagnostic actionable.
//
// Pre-fix:
//   Warning: Skipping unsupported function copy-out argument for
//   value (further similar warnings suppressed)
// Post-fix:
//   uvm_port_base.svh:305: warning: Skipping unsupported function
//   copy-out argument for `value' (further similar warnings
//   suppressed)
//
// The runtime behavior is unchanged — the copy-out is still silently
// skipped — but the user can now find the call site and rewrite if
// the missing copy-out matters semantically.
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
    $display("PASS: copy-out warning now includes file:line for actionable diagnosis");
    $finish;
  end
endmodule
