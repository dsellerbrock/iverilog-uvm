module sv_assert_sequence_mutual_cycle_fail;reg clk=0;
 sequence A; B; endsequence
 sequence B; A; endsequence
 assert property (@(posedge clk) A);
endmodule
