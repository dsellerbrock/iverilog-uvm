// Phase 62 / C4: uvm_cmdline_processor.get_args and get_arg_values
// must return the actual vvp argv via DPI.
//
// Pre-fix (iverilog 98792215b): of_DPI_CALL_STR popped from str stack
// but the call site at vvp_process.c had pushed `int` via %load/vec4.
// uvm_dpi_get_next_arg_c was invoked with garbage; argv[] stayed
// empty.  Fix packs per-arg type signature into the function-name
// string with `|` separator so the runtime opcodes pop each arg from
// its right stack.
//
// This test runs without DPI plusargs and exercises only that the
// cmdline processor can be instantiated and called without crashing.
// (Real argv extraction needs `vvp -d uvm_dpi.so +foo +bar=...`,
// which the regression harness doesn't pass — covered manually.)
`timescale 1ns/1ps
`include "uvm_macros.svh"

module top;
  import uvm_pkg::*;

  initial begin
    uvm_cmdline_processor clp;
    string args[$];
    clp = uvm_cmdline_processor::get_inst();
    if (clp == null) begin
      $display("FAIL: get_inst returned null");
      $fatal(1, "C4 regression: cmdline_processor singleton broken");
    end
    clp.get_args(args);
    // Without DPI lib loaded, args may be empty — that's OK; the test
    // verifies the call doesn't crash or trigger pop_str underflow.
    $display("PASS: cmdline_processor.get_args returned %0d args", args.size());
    $finish;
  end
endmodule
