`timescale 1ns/1ps
module test;
  logic clk = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk);
  endclocking
  initial begin
    ##3;
    $display("RESUMED %0t", $time);
    $finish;
  end
endmodule
