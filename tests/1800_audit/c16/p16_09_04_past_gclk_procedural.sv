`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic sig = 0;
  logic sampled;
  always #5 clk = ~clk;

  global clocking gclk @(posedge clk); endclocking

  // §16.9.4 permits global past sampled-value functions in procedural code.
  initial begin
    @(negedge clk);
    sig = 1;
    @(posedge clk);
    #1;
    sampled = $past_gclk(sig);
    if (sampled !== 1'b1)
      $fatal(1, "$past_gclk procedural sample was %b, expected 1", sampled);
    $display("PASSED: §16.9.4 procedural $past_gclk");
    $finish(0);
  end
endmodule
