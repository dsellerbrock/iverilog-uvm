`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic a = 0, b = 0;
  always #5 clk = ~clk;

  sequence default_pair(logic x = a, logic y = b);
    x ##1 y;
  endsequence : default_pair

  assert property (@(posedge clk) default_pair())
    else $fatal(1, "default sequence arguments failed");

  initial begin
    #1 a = 1'b1; b = 1'b1;
    #30 $display("PASSED");
    $finish(0);
  end
endmodule
