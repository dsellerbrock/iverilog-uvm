module issue912_timezero_default_sample;
  bit clk0 = 0;
  bit clk1 = 0;
  logic declaration_initialized = 0;
  logic uninitialized;
  logic preponed_control = 0;
  integer passed = 0;

  initial begin
    #0 clk0 = 1;
    #1 clk1 = 1;
  end

  initial begin
    declaration_initialized = 1;
    uninitialized = 1;
    #1 preponed_control = 1;
  end

  assert property (@(posedge clk0) declaration_initialized === 1'b0)
    passed = passed + 1;
  else $fatal(1, "issue912: declaration default was not sampled");

  assert property (@(posedge clk0) uninitialized === 1'bx)
    passed = passed + 1;
  else $fatal(1, "issue912: uninitialized default was not sampled");

  assert property (@(posedge clk1) preponed_control === 1'b0)
    passed = passed + 1;
  else $fatal(1, "issue912: later Preponed sampling changed");

  initial begin
    #2;
    if (passed != 3)
      $fatal(1, "issue912: expected 3 assertion passes, got %0d", passed);
    $display("issue912 time-zero default sampling PASS");
    $finish;
  end
endmodule
