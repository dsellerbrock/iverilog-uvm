module main;
  bit src_clk=0, dst_clk=0, a=0, b=0, check_match=0;
  always #5 src_clk=~src_clk;
  always #11 dst_clk=~dst_clk;
  sequence source_seq;
    @(posedge src_clk) a ##1 b;
  endsequence
  assert property (@(posedge dst_clk) check_match |-> source_seq.matched)
    else $fatal(1, "cross-clock matched sequence did not complete");
  initial begin
    #4 a=1;
    #9 begin a=0; b=1; end
    #3 b=0;
    #16 check_match=1;
    #2;
    $display("PASSED");
    $finish(0);
  end
endmodule
