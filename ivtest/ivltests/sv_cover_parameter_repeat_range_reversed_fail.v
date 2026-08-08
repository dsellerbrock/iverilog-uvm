// A finite consecutive-repetition range requires LO <= HI.  Both overridden
// values remain known and nonnegative, so this compile/elaboration failure
// discriminates the ordering guard from the individual bound-validity guards.
module cover_parameter_repeat_range_reversed_checker #(
  parameter int LO = 1,
  parameter int HI = 4
) (
  input logic clk,
  input logic keep,
  input logic result
);
  invalid: cover property (@(posedge clk) keep[*LO:HI] |-> result);
endmodule

module sv_cover_parameter_repeat_range_reversed_fail;
  logic clk;
  logic keep;
  logic result;

  cover_parameter_repeat_range_reversed_checker #(
    .LO(3),
    .HI(2)
  ) dut (.*);
endmodule
