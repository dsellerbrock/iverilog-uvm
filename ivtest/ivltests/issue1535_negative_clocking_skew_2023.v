module issue1535_negative_clocking_skew;
  timeunit 1ns;
  timeprecision 1ps;
  logic clk, d, e;
  clocking cb @(posedge clk);
    input #(-1) d;
    input #(-1ns) e;
  endclocking
endmodule
