`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  logic q;
  clocking cb @(posedge clk); output q; endclocking
  assign q=0;
  initial #50 $finish;
endmodule
