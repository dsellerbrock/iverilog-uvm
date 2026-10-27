`timescale 1ns/1ns
module tb;
  bit c0=0; initial #0 c0=1;
  logic u=1;
  assert property (@(posedge c0) u) $display("S3c PASS %0t",$time) else $display("S3c FAIL %0t",$time);
  initial #50 $finish;
endmodule
