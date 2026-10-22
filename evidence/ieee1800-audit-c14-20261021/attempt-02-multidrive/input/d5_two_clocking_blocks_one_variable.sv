`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  reg j=0;
  clocking pe @(posedge clk); output j; endclocking
  clocking ne @(negedge clk); output j; endclocking
  always @(j) $display("%0t j=%b", $time, j);
  initial begin @(pe) pe.j<=1; @(ne) ne.j<=0; #12 pe.j<=1; end
  initial #50 $finish;
endmodule
