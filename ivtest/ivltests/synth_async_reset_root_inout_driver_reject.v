`begin_keywords "1800-2012"

module synth_async_reset_root_inout_driver_reject (
  input  wire       clk,
  input  wire [1:0] controls,
  input  wire       data,
  inout  wire       rst_n,
  output logic      q
);
  assign rst_n = controls[0];

  // The root inout remains an independent external source even though its
  // nexus also has one fixed-select output driver. It is not an identity alias
  // of controls[0], so the event/condition pair must remain rejected.
  always_ff @(posedge clk or negedge controls[0])
    if (!rst_n)
      q <= 1'b0;
    else
      q <= data;
endmodule

`end_keywords
