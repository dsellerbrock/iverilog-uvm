`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic sig = 0;
  always #5 clk = ~clk;
  global clocking gclk @(posedge clk); endclocking

  initial begin
    @(negedge clk); sig = 1;
    @(posedge clk); #1;
    if ($rose_gclk(sig) !== 1'b1)
      $fatal(1, "$rose_gclk expected 1 after sampled 0-to-1 transition");
    @(posedge clk); #1;
    if ($stable_gclk(sig) !== 1'b1)
      $fatal(1, "$stable_gclk expected 1 while the global sample holds");
    @(negedge clk); sig = 0;
    @(posedge clk); #1;
    if ($fell_gclk(sig) !== 1'b1)
      $fatal(1, "$fell_gclk expected 1 after sampled 1-to-0 transition");
    $display("PASSED: §16.9.4 $rose_gclk, $stable_gclk, $fell_gclk");
    $finish(0);
  end
endmodule
