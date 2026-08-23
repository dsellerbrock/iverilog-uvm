`begin_keywords "1800-2012"

module synth_async_reset_multidriver_select_reject (
  input  logic       clk,
  input  logic [1:0] controls,
  input  logic       ext_rst_n,
  input  logic       data,
  output logic       q
);
  wire rst_n;
  assign rst_n = controls[0];
  assign rst_n = ext_rst_n;

  // rst_n has both the fixed-select source and an independent driver. It is
  // not an identity alias of controls[0], so this event/condition pair must
  // remain a multiple-clock rejection during synchronous synthesis.
  always_ff @(posedge clk or negedge controls[0])
    if (!rst_n)
      q <= 1'b0;
    else
      q <= data;
endmodule

`end_keywords
