`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  int cnt=0; always @(posedge clk) cnt<=cnt+1;
  assert property (@(posedge clk) cnt!=2) else $display("S1 FAIL %0t",$time);
  initial #50 $finish;
endmodule
