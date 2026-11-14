// Issue #3261 (IEEE 1800-2023 37.47, 37.1): vpiDelay of a continuous
// assignment is its delay expression, or a vpiListOp of rise, fall and
// decay. $probe checks it.
module top;
  wire w0, w1, w2, w3;
  reg x;
  parameter D = 7;
  assign w0 = x;
  assign #5 w1 = x;
  assign #(D, 2) w2 = x;
  assign #(1, 2, 3) w3 = x;
  initial #10 $probe;
endmodule
