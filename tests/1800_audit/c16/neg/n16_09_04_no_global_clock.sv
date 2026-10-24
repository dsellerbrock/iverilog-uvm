// IEEE 1800-2017/2023 §16.9.4: global-clock sampled-value functions require
// a global clocking declaration in the design.
module test;
  logic clk = 0;
  logic sig = 0;
  always #5 clk = ~clk;
  assert property (@(posedge clk) $past_gclk(sig) == 0);
endmodule
