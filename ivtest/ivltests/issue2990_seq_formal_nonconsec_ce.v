// IEEE 1800-2023 16.8.1 / 16.9.2: nonconsecutive repetition takes the same
// expression_or_dist operand, so a sequence-typed formal is illegal there.
module issue2990_seq_formal_nonconsec_ce;
  bit clk, a;
  sequence s(sequence arg); arg[=2]; endsequence
  cover property (@(posedge clk) s(a));
endmodule
