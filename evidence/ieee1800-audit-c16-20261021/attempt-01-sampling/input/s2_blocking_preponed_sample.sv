`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  int b=0; always @(posedge clk) b=b+1;
  assert property (@(posedge clk) b!=2) else $display("S2 FAIL %0t",$time);
  initial #50 $finish;
endmodule
