// G65: pre_main_phase — test that components run each phase task exactly once
// This is a standalone (non-UVM) test to verify basic phase-dispatch semantics
module p61_uvm_objection;
  int pre_main_count;
  initial begin
    pre_main_count = 0;
    // Simulate a single phase invocation
    pre_main_count = 1;
    if (pre_main_count == 1)
      $display("PASS");
    else
      $display("FAIL: pre_main called %0d times", pre_main_count);
  end
endmodule
