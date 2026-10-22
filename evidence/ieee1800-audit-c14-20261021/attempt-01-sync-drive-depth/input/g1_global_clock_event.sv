`timescale 1ns/1ps
module test;
  logic clk = 0;
  integer n = 0;
  always #5 clk = ~clk;
  global clocking sys @(posedge clk);
  endclocking
  always @($global_clock) n = n + 1;
  initial begin
    repeat (3) @(posedge clk);
    #1;
    $display("GLOBAL %0d", n);
    $finish;
  end
endmodule
