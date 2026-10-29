module sv_assert_first_match_sequence_local_scope_fail;
  logic clk = 0;
  always #5 clk = ~clk;

  sequence local_sequence;
    int local_value;
    1'b1;
  endsequence

  cover property (@(posedge clk) first_match(local_sequence, local_value = 1));
endmodule
