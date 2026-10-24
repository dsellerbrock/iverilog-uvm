module main;
  bit src_clk=0, dst_clk=0, a=0, b=0;
  int matched_hits=0;
  always #5 src_clk=~src_clk;
  always #11 dst_clk=~dst_clk;
  sequence source_seq;
    @(posedge src_clk) a ##1 b;
  endsequence
  sequence destination_seq;
    @(posedge dst_clk) source_seq.matched;
  endsequence
  cover property (destination_seq) matched_hits++;
  initial begin
    #4 a=1;
    #9 begin a=0; b=1; end
    #3 b=0;
    #18;
    if (matched_hits != 1)
      $fatal(1, "cross-clock matched count=%0d, expected 1", matched_hits);
    $display("PASSED");
    $finish(0);
  end
endmodule
