// A bounded delay window requires a nonnegative upper bound no smaller than
// its lower bound (IEEE 1800-2017 16.9.2).  HI is overridden per instance, so
// this invalid [2:1] window must be rejected during elaboration.  The CE test
// requires a nonzero compiler exit before any simulator is run.
module cover_parameter_window_reversed_checker #(
  parameter int HI = 8
) (
  input logic clk,
  input logic a,
  input logic b
);
  invalid: cover property (@(posedge clk) a |-> ##[2:HI] b);
endmodule

module sv_cover_parameter_window_reversed;
  logic clk = 0;
  logic a = 0;
  logic b = 0;

  cover_parameter_window_reversed_checker #(.HI(1)) dut (.*);
endmodule
