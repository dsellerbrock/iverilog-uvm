// Issue #2989: a negative actual for a sequence-formal cycle delay is an
// invalid delay (IEEE 1800-2017/2023 16.7).
module issue2989_seq_formal_delay_fail;
  bit clk = 0;
  sequence s(int d); 1'b1 ##d 1'b1; endsequence
  cover property (@(posedge clk) s(-1));
endmodule
