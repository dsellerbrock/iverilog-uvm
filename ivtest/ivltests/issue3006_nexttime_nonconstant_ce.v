// IEEE 1800-2023 16.12.10: the index is a constant expression; a variable
// index is illegal, and one that an instance override could change is
// refused rather than folded to the declaration default.
module issue3006_nexttime_nonconstant_ce #(parameter int P = 2);
  bit clk, a;
  int v = 1;
  assert property (@(posedge clk) s_nexttime[v] (a));
  assert property (@(posedge clk) nexttime[P] (a));
endmodule
