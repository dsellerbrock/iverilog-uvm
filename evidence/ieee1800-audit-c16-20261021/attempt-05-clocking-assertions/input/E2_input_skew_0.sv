`timescale 1ns/1ns
module tb;
  logic a = 1;
  bit clk;
  always #5 clk = ~clk;
  initial begin #12 a = 0; #6 a = 1; end
  initial #40 $finish;
  clocking cbs @(posedge clk);
    input #0 a;
  endclocking
  assert property (@(posedge clk) cbs.a)
    else $display("E2 FAIL %0t", $time);
endmodule
