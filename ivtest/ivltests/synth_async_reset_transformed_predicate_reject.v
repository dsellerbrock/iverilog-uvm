`begin_keywords "1800-2012"

module synth_async_reset_transformed_predicate_reject (
  input  logic clk,
  input  logic rst_n,
  input  logic data,
  output logic q_inverted_compare,
  output logic q_constant_compare
);
  always_ff @(posedge clk or negedge rst_n)
    if ((~rst_n) == 1'b0)
      q_inverted_compare <= 1'b0;
    else
      q_inverted_compare <= data;

  always_ff @(posedge clk or negedge rst_n)
    if ((rst_n ^ rst_n) == 1'b0)
      q_constant_compare <= 1'b0;
    else
      q_constant_compare <= data;
endmodule

`end_keywords
