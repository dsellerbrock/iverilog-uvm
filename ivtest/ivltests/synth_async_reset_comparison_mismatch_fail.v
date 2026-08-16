`begin_keywords "1800-2012"

module synth_async_reset_comparison_mismatch_fail (
  input  logic clk,
  input  logic reset_n,
  input  logic reset_h,
  input  logic other,
  output logic q_bad_low,
  output logic q_bad_high,
  output logic q_bad_other,
  output logic q_bad_constant
);
  always_ff @(posedge clk or negedge reset_n)
    if (reset_n == 1)
      q_bad_low <= 1'b0;
    else
      q_bad_low <= 1'b1;

  always_ff @(posedge clk or posedge reset_h)
    if (reset_h == 0)
      q_bad_high <= 1'b0;
    else
      q_bad_high <= 1'b1;

  always_ff @(posedge clk or negedge reset_n)
    if (reset_n == other)
      q_bad_other <= 1'b0;
    else
      q_bad_other <= 1'b1;

  always_ff @(posedge clk or negedge reset_n)
    if (reset_n == 2)
      q_bad_constant <= 1'b0;
    else
      q_bad_constant <= 1'b1;
endmodule

`end_keywords
