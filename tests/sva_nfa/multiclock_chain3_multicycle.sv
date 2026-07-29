// M9-7 residual: multi-cycle local chains on BOTH sides of the SECOND
// clock-flow boundary in a three-domain sequence (IEEE 1800-2017
// 16.13.1) -- `@(c1) req |=> @(c2) b1 ##2 b2 ##1 @(c3) cc1 ##1 cc2'.
// Domain 1 (c2) is itself a two-tick chain (`b1 ##2 b2'); its match
// forwards to domain 2 (c3), which is also a two-tick chain
// (`cc1 ##1 cc2'). Both generalize the same counting pipeline the
// 2-domain consequent already uses.
//
// NFA-EXPECT-FALLBACK
//
// c1 posedges 5,15,25,... ; c2 posedges 7,21,35,49,63,77,... ;
// c3 posedges 11,33,55,77,99,...
//   req@15 matches. domain 1 starts at the first c2 tick strictly after
//   15 (21, b1), then ##2 c2 ticks later (49, b2) -- 21->35->49.
//   Boundary ##1 to c3: domain 2 starts at the first c3 tick strictly
//   after 49 (55, cc1), then ##1 (77, cc2) -- real PASS@77. Every other
//   c1 tick in [0,86] (5,25,35,45,55,65,75,85 -- 8 of them) is a vacuous
//   antecedent miss, so the run totals 9 PASS, 0 FAIL.
module multiclock_chain3_multicycle;
  bit c1=0, c2=0, c3=0;
  bit req=0, b1=0, b2=0, cc1=0, cc2=0;
  always #5  c1 = ~c1;
  always #7  c2 = ~c2;
  always #11 c3 = ~c3;

  int pass_cnt=0, fail_cnt=0;
  assert property (@(posedge c1) req |=> @(posedge c2) b1 ##2 b2 ##1
                    @(posedge c3) cc1 ##1 cc2)
    begin pass_cnt++; $display("MC [%0t] PASS", $time); end
  else
    begin fail_cnt++; $display("MC [%0t] FAIL", $time); end

  initial begin
    #14 req = 1;
    #1  req = 0;         // t=15 antecedent match
    #5  b1 = 1;           // t=20, before c2@21
    #1  b1 = 0;            // t=21
    #27 b2 = 1;             // t=48, before c2@49
    #1  b2 = 0;              // t=49: domain-1 completes, ##1 to c3
    #5  cc1 = 1;              // t=54, before c3@55
    #1  cc1 = 0;               // t=55
    #21 cc2 = 1;                // t=76, before c3@77
    #1  cc2 = 0;                 // t=77: domain-2 completes -> real PASS
    #9;                            // t=86

    if (pass_cnt == 9 && fail_cnt == 0)
      $display("PASSED");
    else
      $display("FAILED -- pass=%0d fail=%0d, expected 9/0",
                pass_cnt, fail_cnt);
    $finish(0);
  end
endmodule
