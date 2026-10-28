module issue1359_unknown_named_sequence;
  bit clk, a;
  sequence one(x);
    x;
  endsequence
  assert property (@(posedge clk) one(.missing(a)));
endmodule
