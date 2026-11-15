// Issue #3137: a hierarchically named interface clocking-block input with a
// numeric input skew cannot be an assertion operand (IEEE 1800-2017/2023
// 16.5.1).
interface bif(input logic clk);
  logic a = 1;
  clocking cb @(posedge clk); input #2 a; endclocking
endinterface
module tb;
  logic clk = 0;
  bif bus(clk);
  assert property (@(posedge bus.clk) bus.cb.a);
endmodule
