`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic sig = 0;
  always #5 clk = ~clk;

  global clocking gclk @(posedge clk); endclocking

  // At the second sampled rise, sig remains high at the next global tick.
  assert property (@($global_clock) $rising_gclk(sig) |=> $future_gclk(sig) == 1'b1)
    else $fatal(1, "future global-clock sample mismatch");

  initial begin
    @(negedge clk);
    sig = 1;
    #30;
    $display("PASSED: §16.9.4 future global clocking functions");
    $finish(0);
  end
endmodule
