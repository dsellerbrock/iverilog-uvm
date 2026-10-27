`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  logic k=0;
  clocking e @(edge clk); output k; endclocking
  always @(k) $display("%0t k=%b", $time, k);
  initial begin @(e) e.k<=1; @(e) e.k<=0; @(e) e.k<=1; end
  initial #50 $finish;
endmodule
