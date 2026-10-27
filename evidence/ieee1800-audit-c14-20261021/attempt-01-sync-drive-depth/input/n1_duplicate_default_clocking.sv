`timescale 1ns/1ps
module test;
  logic clk = 0;
  always #5 clk = ~clk;
  default clocking cb1 @(posedge clk);
  endclocking
  default clocking cb2 @(posedge clk);
  endclocking
endmodule
