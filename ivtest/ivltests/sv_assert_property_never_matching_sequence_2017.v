module sv_assert_property_never_matching_sequence;
  logic clk = 0;
  always #5 clk = ~clk;

  sequence impossible_seq;
    (1'b1) intersect (1'b1 ##1 1'b1);
  endsequence

  assert property (@(posedge clk) impossible_seq);
endmodule
