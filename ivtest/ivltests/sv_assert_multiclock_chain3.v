// M9-7 residual: a three-clock-domain sequence chain
// `@(c1) req |=> @(c2) b ##1 @(c3) c' (IEEE 1800-2017 16.13.1).
// Generalizes the 2-domain request/ack handoff (sv_assert_multiclock_*)
// to N domains: domain 1 (c2) forwards its own match count to domain
// 2's (c3) request counter across its own ##0/##1 boundary instead of
// running a user action; domain 2 computes the real verdict. Covers:
// a basic three-domain chain (with its cover sibling), overlapping
// attempts that become due at the SAME middle-domain tick, and
// multi-cycle local chains on both sides of the second boundary. Each
// scenario uses its own clock nets so they cannot interact.
module main;
  // ---- basic: single real completion + vacuous antecedent misses ----
  bit bc1=0, bc2=0, bc3=0;
  bit breq=0, bb=0, bc=0;
  always #5  bc1 = ~bc1;   // posedges 5,15,25,35,45,55
  always #7  bc2 = ~bc2;   // posedges 7,21,35,49
  always #11 bc3 = ~bc3;   // posedges 11,33,55,77

  int basic_pass=0, basic_fail=0, basic_cov=0;
  assert property (@(posedge bc1) breq |=> @(posedge bc2) bb ##1
                    @(posedge bc3) bc)
    basic_pass++;
  else
    basic_fail++;
  cover property (@(posedge bc1) breq |=> @(posedge bc2) bb ##1
                   @(posedge bc3) bc)
    basic_cov++;

  // ---- overlap: two matches on consecutive c1 ticks, coincident at
  // the same middle-domain (c2) tick ----
  bit oc1=0, oc2=0, oc3=0;
  bit oreq=0, ob=0, oc=0;
  always #5  oc1 = ~oc1;   // posedges 5,15,25,35,45,55,65
  always #11 oc2 = ~oc2;   // posedges 11,33,55,77
  always #10 oc3 = ~oc3;   // posedges 10,30,50,70,90

  int ov_pass=0, ov_fail=0;
  assert property (@(posedge oc1) oreq |=> @(posedge oc2) ob ##1
                    @(posedge oc3) oc)
    ov_pass++;
  else
    ov_fail++;

  // ---- multi-cycle: two-tick local chains on BOTH sides of the
  // second boundary ----
  bit mc1=0, mc2=0, mc3=0;
  bit mreq=0, mb1=0, mb2=0, mcc1=0, mcc2=0;
  always #5  mc1 = ~mc1;   // posedges 5,15,25,...
  always #7  mc2 = ~mc2;   // posedges 7,21,35,49,63,77,...
  always #11 mc3 = ~mc3;   // posedges 11,33,55,77,99,...

  int mcyc_pass=0, mcyc_fail=0;
  assert property (@(posedge mc1) mreq |=> @(posedge mc2) mb1 ##2 mb2 ##1
                    @(posedge mc3) mcc1 ##1 mcc2)
    mcyc_pass++;
  else
    mcyc_fail++;

  initial begin
    // basic: req@15 -> b@21 -> c@33 (real PASS); vacuous at 5,25,35,45,55
    #14 breq = 1;
    #1  breq = 0;
    #5  bb = 1;
    #1  bb = 0;
    #11 bc = 1;
    #1  bc = 0;
    #27;   // t=60
  end

  initial begin
    // overlap: req@15 AND req@25, both due at c2@33; b@33; c@50 (2x PASS)
    #14 oreq = 1;
    #1  oreq = 0;
    #9  oreq = 1;
    #1  oreq = 0;
    #6  ob = 1;
    #3  ob = 0;
    #15 oc = 1;
    #2  oc = 0;
    #20;   // t=71
  end

  initial begin
    // multi-cycle: req@15 -> b1@21 ##2-> b2@49 -> ##1-> cc1@55 ##1-> cc2@77
    #14 mreq = 1;
    #1  mreq = 0;
    #5  mb1 = 1;
    #1  mb1 = 0;
    #27 mb2 = 1;
    #1  mb2 = 0;
    #5  mcc1 = 1;
    #1  mcc1 = 0;
    #21 mcc2 = 1;
    #1  mcc2 = 0;
    #9;   // t=86
  end

  initial begin
    #100;
    // All three scenarios share a c1 period of 10 (10 ticks in [0,100)),
    // so each totals 10 PASS: one c1 tick per scenario carries a real
    // antecedent match (two for the overlap case, both discharging
    // together), every other c1 tick is a vacuous antecedent miss that
    // also reports through the pass action (matching the existing
    // single-boundary |=> semantics).
    if (basic_pass != 10 || basic_fail != 0)
      $display("FAILED -- basic chain pass/fail=%0d/%0d, expected 10/0",
                basic_pass, basic_fail);
    else if (basic_cov != 1)
      $display("FAILED -- basic chain cover count=%0d, expected 1",
                basic_cov);
    else if (ov_pass != 10 || ov_fail != 0)
      $display("FAILED -- overlapping-attempt chain pass/fail=%0d/%0d, expected 10/0; a coincident middle-domain obligation was lost or duplicated",
                ov_pass, ov_fail);
    else if (mcyc_pass != 10 || mcyc_fail != 0)
      $display("FAILED -- multi-cycle chain pass/fail=%0d/%0d, expected 10/0",
                mcyc_pass, mcyc_fail);
    else
      $display("PASSED");
    $finish(0);
  end
endmodule
