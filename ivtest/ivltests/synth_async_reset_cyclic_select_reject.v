`begin_keywords "1800-2012"

module synth_async_reset_cyclic_select_reject (
  input  logic clk,
  input  logic reset_condition_n,
  input  logic data,
  output logic q
);
  wire [0:0] reset_loop_n;
  assign reset_loop_n = reset_loop_n[0];

  // The zero-delay assignment nexus-merges the fixed select's output with its
  // source. Canonical reset-source recovery must terminate on that cycle, then
  // conservatively reject the unrelated reset condition as a second clock.
  always_ff @(posedge clk or negedge reset_loop_n)
    if (!reset_condition_n)
      q <= 1'b0;
    else
      q <= data;
endmodule

`end_keywords
