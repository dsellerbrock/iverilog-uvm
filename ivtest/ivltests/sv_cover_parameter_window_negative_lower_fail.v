// A symbolic consequence-window lower bound is resolved after instance
// parameter overrides and must remain nonnegative.  HI=3 is valid and remains
// above LO=-1, isolating the lower-bound validity guard.
module cover_parameter_window_negative_lower_checker #(
  parameter int LO = 1,
  parameter int HI = 3
) (
  input logic clk,
  input logic a,
  input logic b
);
  invalid: cover property (@(posedge clk) a |-> ##[LO:HI] b);
endmodule

module sv_cover_parameter_window_negative_lower_fail;
  logic clk;
  logic a;
  logic b;

  cover_parameter_window_negative_lower_checker #(.LO(-1)) dut (.*);
endmodule
