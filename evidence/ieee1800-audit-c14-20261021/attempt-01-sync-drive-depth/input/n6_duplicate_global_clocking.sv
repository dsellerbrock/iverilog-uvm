`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic clk2 = 0;
  always #5 clk = ~clk;
  always #7 clk2 = ~clk2;
  global clocking cb1 @(posedge clk);
  endclocking
  global clocking cb2 @(posedge clk2);
  endclocking
endmodule
