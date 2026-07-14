// IEEE 1800-2017 14.12: at most one default clocking per module.
module top;
  logic clk = 0;
  clocking cb1 @(posedge clk); endclocking
  clocking cb2 @(posedge clk); endclocking
  default clocking cb1;
  default clocking cb2;
endmodule
