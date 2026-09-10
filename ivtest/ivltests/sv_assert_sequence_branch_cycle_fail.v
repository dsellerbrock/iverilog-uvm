module sv_assert_sequence_branch_cycle_fail;reg clk=0;
 sequence A; A ##1 A; endsequence
 assert property (@(posedge clk) A);
endmodule
