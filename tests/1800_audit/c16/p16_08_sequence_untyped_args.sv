`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic a = 0, b = 0;
  always #5 clk = ~clk;

  sequence untyped_pair(x, y);
    x ##1 y;
  endsequence

  assert property (@(posedge clk) untyped_pair(a, b))
    else $fatal(1, "untyped sequence arguments failed");

  initial begin
    #1 a = 1'b1; b = 1'b1;
    #30 $display("PASSED");
    $finish(0);
  end
endmodule
