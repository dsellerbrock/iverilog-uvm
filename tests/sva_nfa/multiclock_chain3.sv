// M9-7 residual: a THREE-clock-domain sequence chain
// `@(c1) req |=> @(c2) b ##1 @(c3) c' (IEEE 1800-2017 16.13.1). Domain 0
// (c1) is the existing antecedent pipeline unchanged; domain 1 (c2) and
// domain 2 (c3) are each a counting pipeline exactly like the 2-domain
// consequent, chained: domain 1 forwards its own match COUNT to domain
// 2's request counter across its own ##0/##1 boundary instead of a user
// action, and domain 2 computes the real verdict. Like the 2-domain
// D.1/D.2 lowering this is a dedicated construction that runs regardless
// of IVL_SVA_NFA, so the two builds are identical by construction (a
// parity test that does not engage the NFA slot pool).
//
// NFA-EXPECT-FALLBACK
//
// c1 posedges 5,15,25,35,45,55 ; c2 posedges 7,21,35,49 ; c3 posedges
// 11,33,55,77.
//   req@15 matches; due-after tick in c2 is 21; b@21 holds; forwarded
//   ##1 to c3, due-after tick 33; c@33 HOLDS -> real PASS@33.
//   Every c1 tick with req==0 (5,25,35,45,55) is a vacuous antecedent
//   miss and also reports through the pass action (matching the
//   existing single-boundary |=> semantics), so with 5 such ticks in
//   [0,60] plus the one real completion the run totals 6 PASS, 0 FAIL.
module multiclock_chain3;
  bit c1=0, c2=0, c3=0;
  bit req=0, b=0, c=0;
  always #5  c1 = ~c1;
  always #7  c2 = ~c2;
  always #11 c3 = ~c3;

  int pass_cnt=0, fail_cnt=0;
  assert property (@(posedge c1) req |=> @(posedge c2) b ##1 @(posedge c3) c)
    begin pass_cnt++; $display("A [%0t] PASS", $time); end
  else
    begin fail_cnt++; $display("A [%0t] FAIL", $time); end

  // Sibling cover of the identical sequence: only the real consequent
  // completion counts (a vacuous antecedent miss is a non-match, not a
  // verdict), so this counts exactly 1 over the same stimulus.
  int cov_cnt=0;
  cover property (@(posedge c1) req |=> @(posedge c2) b ##1 @(posedge c3) c)
    cov_cnt++;

  initial begin
    #14 req = 1;      // t=14, before c1@15
    #1  req = 0;      // t=15: antecedent match
    #5  b = 1;        // t=20, before c2@21
    #1  b = 0;        // t=21: domain-1 (c2) holds -> forwards ##1 to c3
    #11 c = 1;        // t=32, before c3@33
    #1  c = 0;        // t=33: domain-2 (c3) holds -> real PASS
    #27;              // t=60
    if (pass_cnt == 6 && fail_cnt == 0 && cov_cnt == 1)
      $display("PASSED");
    else
      $display("FAILED -- pass=%0d fail=%0d cov=%0d, expected 6/0/1",
                pass_cnt, fail_cnt, cov_cnt);
    $finish(0);
  end
endmodule
