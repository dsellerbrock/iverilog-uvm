// Multiple edge events that are not read by the process body are competing
// clocks, not asynchronous controls. Synthesis must reject this shape without
// forwarding an incomplete event vector into the statement synthesizer.
module synth_multiple_clocks_reject(
  input  logic clk_a,
  input  logic clk_b,
  input  logic en,
  input  logic d,
  output logic q
);
  always @(posedge clk_a or posedge clk_b)
    if (en)
      q <= d;
endmodule
