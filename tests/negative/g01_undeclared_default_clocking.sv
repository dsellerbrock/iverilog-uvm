// IEEE 1800-2017 14.12: `default clocking id;` must name a clocking
// block declared in the same scope.
module top;
  logic clk = 0;
  default clocking nosuch;
endmodule
