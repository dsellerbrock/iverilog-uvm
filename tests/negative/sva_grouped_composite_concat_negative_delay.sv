// IEEE 1800-2017 16.9.1 requires a cycle delay to be nonnegative.  The
// grouped-composite continuation route must retain that legality check; it
// must not accept an invalid delay merely to avoid the old syntax error.
module sva_grouped_composite_concat_negative_delay;
  logic clk = 0, a = 0, b = 0, c = 0, d = 0;
  sequence bad;
    @(posedge clk) ((a ##1 b) and (a ##2 c)) ##-1 d;
  endsequence
  a0: assert property (bad);
endmodule
