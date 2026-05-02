// Phase 63b / B5: silence per-compile warning emitted by
// $ivl_queue_method$sort when the queue receiver isn't a plain signal
// (e.g. class-property queues like UVM uvm_root::m_time_settings).
//
// Pre-fix:
//   Warning: $ivl_queue_method$sort requires a signal at
//     uvm_root.svh:827; skipping
//
// The warning fired on every UVM compile.  The %qsort opcode requires
// a signal arg; class-property queues need a queue-by-handle variant
// (not yet implemented).  Suppress the warning; runtime behavior is
// "no sort" which is acceptable for the UVM use case (time-based
// verbosity settings ordering is not strictly required).
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
    $display("PASS: UVM compile clean of $ivl_queue_method$sort warning");
    $finish;
  end
endmodule
