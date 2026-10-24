`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  bit [3:0] v=0;
  clocking cb @(posedge clk); output v; endclocking
  always @(v) $display("%0t v=%h", $time, v);
  initial begin #8 cb.v<=1; #4 cb.v<=2; end
  initial #50 $finish;
endmodule
