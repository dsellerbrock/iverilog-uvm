// M9-7: multiclocked non-overlapping implication with FIXED-length
// chains on both sides: `@(c1) a0 ##N a1 |=> @(c2) b0 ##M b1' (IEEE
// 1800-2017 16.13.3). The antecedent chain pipelines in the c1 domain
// (one attempt starts every c1 tick); a completed match raises the
// request counter; the consequent chain pipelines in the c2 domain
// starting at the first c2 tick strictly after the match. Mid-chain
// consequent failures fail at their own tick. Like the D.1 boolean
// handshake this is a dedicated two-domain lowering that runs
// regardless of IVL_SVA_NFA, so the two builds are identical.
//
// NFA-EXPECT-FALLBACK
module multiclock_chain;
  bit clk1 = 0, clk2 = 0;
  bit a = 0, b = 0, c = 0, d = 0;
  always #5 clk1 = ~clk1;    // posedges 5,15,25,35,...
  always #6 clk2 = ~clk2;    // posedges 6,18,30,42,54,...

  // overlapping-attempt case: single-tick consequent
  assert property (@(posedge clk1) a ##1 b |=> @(posedge clk2) c)
    $display("A1 [%0t] PASS", $time);
    else $display("A1 [%0t] FAIL", $time);

  // multi-tick consequent with a ##2 antecedent gap: mid-chain and
  // final-stage verdicts
  assert property (@(posedge clk1) a ##2 b |=> @(posedge clk2) c ##1 d)
    $display("A2 [%0t] PASS", $time);
    else $display("A2 [%0t] FAIL", $time);

  initial begin
    // a true at clk1 posedges 5,15 ; b true at 15,25.
    //  A1 antecedent a##1b matches at 15 (due 18) and 25 (due 30).
    //  A2 antecedent a##2b matches at 25 (a@5? a@5,b@25: a=1@5, gap@15,
    //     b@25 -> match@25, due 30) and (a@15,b@35? b off at 26 -> no).
    // c true at clk2 posedge 18 only; d true at clk2 posedge 42 only.
    //  A1: PASS@18 (c=1), FAIL@30 (c=0).
    //  A2: due@30 stage c fails (c=0) -> FAIL@30.
    a = 1;
    #12 b = 1;          // t12
    #4  a = 0; c = 1;   // t16
    #4  c = 0;          // t20
    #6  b = 0;          // t26
    #14 d = 1;          // t40
    #6  d = 0;          // t46
    #20;                // t66
    // second A2 run, fully passing:
    //  a true [70,78)  -> clk1 posedge 75
    //  b true [92,98)  -> clk1 posedge 95: a ##2 b matches @95
    //  due at the first clk2 posedge strictly after 95 -> 102
    //  c true [98,104)  -> stage c holds @102
    //  d true [110,116) -> stage d holds @114 -> A2 PASS@114
    // (A1 sees no new match: a@75 has no b@85.)
    #4  a = 1;          // t70
    #8  a = 0;          // t78
    #14 b = 1;          // t92
    #6  b = 0; c = 1;   // t98
    #6  c = 0;          // t104
    #6  d = 1;          // t110
    #6  d = 0;          // t116
    #20 $finish(0);
  end
endmodule
