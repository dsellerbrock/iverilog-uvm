module test;
  logic clk = 0;
  logic sig = 0;
  always #5 clk = ~clk;
  global clocking gclk @(posedge clk); endclocking

  // One legal property-context reference to each function named in §16.9.4.
  assert property (@($global_clock) $past_gclk(sig));
  assert property (@($global_clock) $rose_gclk(sig));
  assert property (@($global_clock) $fell_gclk(sig));
  assert property (@($global_clock) $stable_gclk(sig));
  assert property (@($global_clock) $changed_gclk(sig));
  assert property (@($global_clock) $future_gclk(sig) == 1'b0);
  assert property (@($global_clock) $rising_gclk(sig));
  assert property (@($global_clock) $falling_gclk(sig));
  assert property (@($global_clock) $steady_gclk(sig));
  assert property (@($global_clock) $changing_gclk(sig));

  initial begin
    #20;
    $finish(0);
  end
endmodule
