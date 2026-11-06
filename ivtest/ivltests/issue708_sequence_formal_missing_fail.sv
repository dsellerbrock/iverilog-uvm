// IEEE 1800-2017/2023 16.8: an instance shall provide an actual for each
// formal argument that has no default actual.
module issue708_sequence_formal_missing_fail;
  bit clk, a;
  sequence s(x, bit y);
    x ##1 y;
  endsequence
  assert property (@(posedge clk) s(a));
endmodule
