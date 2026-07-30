// C5-1: $past(x, 0) has no meaning — IEEE 1800-2017 16.9.3 requires
// the number-of-ticks argument to be >= 1; the current sample is
// spelled $sampled(x). The pre-fix front end silently CLAMPED depth 0
// (and negatives) to 1, so `$past(x, 0)` quietly meant `$past(x, 1)` —
// a silent off-by-one in any assertion using it as an oracle. It must
// be rejected loudly.
module sva_past_zero_depth;
  logic clk = 0;
  int x = 0;
  ap: assert property (@(posedge clk) $past(x, 0) == 0);
endmodule
