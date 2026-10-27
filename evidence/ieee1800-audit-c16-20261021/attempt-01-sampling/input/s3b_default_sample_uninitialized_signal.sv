`timescale 1ns/1ns
module tb;
  bit c0=0; initial #0 c0=1;
  logic w; initial w=1;
  assert property (@(posedge c0) w) $display("S3b PASS %0t",$time) else $display("S3b FAIL %0t",$time);
  initial #50 $finish;
endmodule
