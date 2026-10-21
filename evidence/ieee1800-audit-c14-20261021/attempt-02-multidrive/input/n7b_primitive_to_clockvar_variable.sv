`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  logic q,a;
  clocking cb @(posedge clk); output q; endclocking
  buf b(q,a);
  initial #50 $finish;
endmodule
