// IEEE 1800-2023 16.8.1: a sequence-typed formal cannot be the operand of
// goto repetition, regardless of the actual (here a Boolean).
module issue2990_seq_formal_goto_ce;
  bit clk, a;
  sequence s(sequence arg); arg[->1]; endsequence
  cover property (@(posedge clk) s(a));
endmodule
