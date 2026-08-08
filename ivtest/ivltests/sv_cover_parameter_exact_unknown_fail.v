// An exact repetition bound must be a known nonnegative constant expression.
// The four-state parameter type and valid declaration default ensure that only
// this instance's all-X override selects the generated elaboration guard.
module cover_parameter_exact_unknown_checker #(
  parameter logic [31:0] K = 2
) (
  input logic clk,
  input logic keep,
  input logic result
);
  invalid: cover property (@(posedge clk) keep[*K] |-> result);
endmodule

module sv_cover_parameter_exact_unknown_fail;
  logic clk;
  logic keep;
  logic result;

  cover_parameter_exact_unknown_checker #(.K(32'hxxxx_xxxx)) dut (.*);
endmodule
