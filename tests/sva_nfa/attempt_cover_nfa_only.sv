// IEEE 16.12.7: cover an implication once per successful nonvacuous
// starting attempt. One successful endpoint cannot cover a failed parent.
module test;
  reg clk=0, start=1, endpoint=1, mixed=1;
  cp: cover property (@(posedge clk) start ##[1:2] endpoint |-> 1'b1);
  cf: cover property (@(posedge clk) start ##[1:2] endpoint |-> mixed);
  initial begin
    #5 clk=1;
    #1 clk=0; start=0;
    #4 clk=1;
    #1 clk=0;
    if (_ivl_sva0_cnt0!=0 || _ivl_sva1_cnt0!=0)
      $fatal(1,"premature implication cover");
    mixed=0;
    #4 clk=1;
    #1 clk=0;
    if (_ivl_sva0_cnt0!=1 || _ivl_sva1_cnt0!=0)
      $fatal(1,"cover counts endpoints instead of parents");
    $display("PASSED");
  end
endmodule
