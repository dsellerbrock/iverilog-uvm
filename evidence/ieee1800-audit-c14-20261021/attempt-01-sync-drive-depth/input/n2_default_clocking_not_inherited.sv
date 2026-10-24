`timescale 1ns/1ps
module parent;
  logic clk = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk);
  endclocking
  child u();
endmodule
module child;
  initial ##1;
endmodule
