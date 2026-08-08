// IEEE 1800-2017 16.9.2 requires nonnegative repetition bounds.  The valid
// declaration defaults ensure that only the per-instance LO=-1 override is
// responsible for this compile/elaboration failure; HI remains known,
// nonnegative, and greater than LO so the lower-bound guard is isolated.
module cover_parameter_repeat_negative_lower_checker #(
  parameter int LO = 1,
  parameter int HI = 3
) (
  input logic clk,
  input logic keep,
  input logic result
);
  invalid: cover property (@(posedge clk) keep[*LO:HI] |-> result);
endmodule

module sv_cover_parameter_repeat_negative_lower_fail;
  logic clk;
  logic keep;
  logic result;

  cover_parameter_repeat_negative_lower_checker #(.LO(-1)) dut (.*);
endmodule
