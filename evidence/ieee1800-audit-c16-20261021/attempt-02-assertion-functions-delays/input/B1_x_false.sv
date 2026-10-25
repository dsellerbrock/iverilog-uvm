`timescale 1ns/1ns
module tb;
  bit clk;
  always #5 clk = ~clk;
  logic a = 0, b = 0;
  initial begin @(posedge clk) a <= 1; @(posedge clk) a <= 0; end
  initial begin repeat (3) @(posedge clk); b <= 1; @(posedge clk); b <= 0; end
  initial #80 $finish;
  logic x = 1'bx;
  assert property (@(posedge clk) x) else $display("B1 FAIL %0t", $time);
endmodule
