`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  assert property (@(posedge clk) 1'b1) $display("S7 PASS %0t",$time); else $display("S7 FAIL %0t",$time);
  initial #50 $finish;
endmodule
