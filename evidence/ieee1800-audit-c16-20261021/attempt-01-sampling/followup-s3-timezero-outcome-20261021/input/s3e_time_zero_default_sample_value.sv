`timescale 1ns/1ns
module tb;
  bit c0=0; initial #0 c0=1;
  logic v=0; initial v=1;
  assert property (@(posedge c0) v) $display("S3e PASS %0t",$time); else $display("S3e FAIL %0t",$time);
  initial #50 $finish;
endmodule
