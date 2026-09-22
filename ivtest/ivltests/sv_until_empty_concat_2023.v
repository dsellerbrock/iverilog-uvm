module empty_until_boundaries_v4;
  bit clk, a, b, c, fire, alternate;
  int failures[8];

  sequence empty0; 1'b1[*0]; endsequence
  sequence finite01; 1'b1[*0:1]; endsequence
  sequence unbounded0; 1'b1[*0:$]; endsequence
  // The alternate branch makes the sequence nondegenerate for other traces;
  // alternate remains 0 in this directed test, so the impossible branch still fails.

  ap_empty0_seq2: assert property (@(posedge clk) fire |-> (empty0 ##2 b)) else failures[2]++;
  ap_seq2_empty0: assert property (@(posedge clk) fire |-> (b ##2 empty0)) else failures[3]++;
  ap_finite01_seq0: assert property (@(posedge clk) fire |-> (finite01 ##0 b)) else failures[4]++;
  ap_unbounded_seq1: assert property (@(posedge clk) fire |-> (unbounded0 ##1 b)) else failures[5]++;
  ap_unbounded_seq2: assert property (@(posedge clk) fire |-> (unbounded0 ##2 b)) else failures[6]++;
  ap_middle_chain: assert property (@(posedge clk) fire |-> (a ##1 b[*0] ##1 c)) else failures[7]++;

  always #5 clk = ~clk;
  initial begin
    clk = 0; a = 0; b = 0; c = 0; fire = 0; alternate = 0;
    #20 fire = 1; a = 1; b = 0; c = 0;
    #10 fire = 0; b = 1;
    #10 b = 0; c = 1;
    #10 c = 0;
    #30;
    $display("V2_FAILURES %0d %0d %0d %0d %0d %0d %0d %0d",
             failures[0], failures[1], failures[2], failures[3], failures[4],
             failures[5], failures[6], failures[7]);
    if (failures[2]!=0 || failures[3]!=1 || failures[4]!=1 || failures[5]!=0 || failures[6]!=0 || failures[7]!=1)
      $fatal(1,"empty concatenation counts");
    $display("PASS empty concatenation boundaries");
    $finish(0);
  end
endmodule
