// Repetition bounds are nonnegative constant expressions (IEEE 1800-2017
// 16.9.2).  Because K is overridden per instance, the earliest focused
// checker can reject this value is elaboration.  This CE test must fail the
// compile; silently constructing a packed [-1:0] implementation is not an
// acceptable interpretation.
module cover_parameter_exact_negative_checker #(
  parameter int K = 4
) (
  input logic clk,
  input logic a
);
  invalid: cover property (@(posedge clk) a[*K]);
endmodule

module sv_cover_parameter_exact_negative;
  logic clk = 0;
  logic a = 0;

  cover_parameter_exact_negative_checker #(.K(-1)) dut (.*);
endmodule
