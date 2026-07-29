// M9-7 residual: overlapping attempts across a three-clock-domain chain
// (IEEE 1800-2017 16.13.1). Two antecedent matches on CONSECUTIVE c1
// ticks are engineered to become due at the SAME c2 tick (no c2 edge
// falls between them), so domain 1's `due' count is 2 there -- the
// counting-pipeline handoff must carry that multiplicity through
// domain 2 without losing or duplicating either obligation.
//
// NFA-EXPECT-FALLBACK
//
// c1 posedges 5,15,25,35,45,55,65 ; c2 posedges 11,33,55,77 ;
// c3 posedges 10,30,50,70,90.
//   req matches at c1@15 AND c1@25: both have "first c2 tick strictly
//   after" == 33 (no c2 edge inside (15,25)), so 2 obligations arrive at
//   domain 1 on the SAME tick and must both discharge together at
//   c3@50 -- 2 real PASSes at the same tick, plus one vacuous PASS per
//   other c1 tick (5,35,45,55,65 -- 5 of them) = 7 PASS, 0 FAIL total.
module multiclock_chain3_overlap;
  bit c1=0, c2=0, c3=0;
  bit req=0, b=0, c=0;
  always #5  c1 = ~c1;
  always #11 c2 = ~c2;
  always #10 c3 = ~c3;

  int pass_cnt=0, fail_cnt=0;
  assert property (@(posedge c1) req |=> @(posedge c2) b ##1 @(posedge c3) c)
    begin pass_cnt++; $display("OV [%0t] PASS", $time); end
  else
    begin fail_cnt++; $display("OV [%0t] FAIL", $time); end

  initial begin
    #14 req = 1;
    #1  req = 0;      // t=15: match #1
    #9  req = 1;      // t=24, before c1@25
    #1  req = 0;      // t=25: match #2 (coincident with #1 at c2@33)
    #6  b = 1;         // t=31, before c2@33
    #3  b = 0;         // t=34
    #15 c = 1;          // t=49, before c3@50
    #2  c = 0;           // t=51
    #20;                  // t=71

    if (pass_cnt == 7 && fail_cnt == 0)
      $display("PASSED");
    else
      $display("FAILED -- pass=%0d fail=%0d, expected 7/0",
                pass_cnt, fail_cnt);
    $finish(0);
  end
endmodule
