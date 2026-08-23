`begin_keywords "1800-2012"

module synth_async_reset_cyclic_value_reject (
  input  logic clk,
  input  logic rst_n,
  input  logic data,
  output logic q
);
  wire [0:0] reset_value;
  assign reset_value = reset_value[0];

  // The event and condition agree, so synthesis reaches constant reset-value
  // recovery. The legal zero-delay select cycle is not a constant and must be
  // rejected promptly instead of recursing until the compiler stack exhausts.
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)
      q <= reset_value;
    else
      q <= data;
endmodule

`end_keywords
