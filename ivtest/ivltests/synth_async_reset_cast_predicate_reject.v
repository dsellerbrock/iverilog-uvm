`begin_keywords "1800-2012"

module synth_async_reset_cast_predicate_reject (
  input  logic clk,
  input  logic rst,
  input  logic data,
  output logic q_signed,
  output logic q_nested_select
);
  typedef struct packed {
    logic        high;
    logic [30:0] low;
  } widened_rst_t;

  // A signed one-bit 1 extends to all ones and is not equal to integer 1.
  always_ff @(posedge clk or posedge rst)
    if ($signed(rst) == 1)
      q_signed <= 1'b0;
    else
      q_signed <= data;

  // The selected high bit of this zero-extended cast is constant zero. Its
  // dependency set still contains rst, but it is not an identity projection.
  always_ff @(posedge clk or negedge rst)
    if (widened_rst_t'($unsigned(rst)).high == 1'b0)
      q_nested_select <= 1'b0;
    else
      q_nested_select <= data;
endmodule

`end_keywords
