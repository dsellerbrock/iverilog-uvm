// M9-7: `cover property' and `disable iff' on a MULTICLOCKED implication
// (IEEE 1800-2017 16.13.3). Both used to be a loud sorry that dropped the
// assertion; both now ride the existing cross-clock request/ack handoff.
//
// Every check here is a COMPARISON against the same property written
// without the feature under test, driven by the same stimulus:
//
//   - the cover count must move opposite the assert's failure count. A
//     cover that silently counted nothing, or one that counted every
//     attempt regardless of the consequent, would look identical to a
//     working one if only its own number were printed.
//   - `disable iff (0)' must be indistinguishable from no disable at all,
//     and `disable iff (1)' must let no verdict escape. The interesting
//     case is in between: attempts started before the reset are aborted,
//     and attempts after it clears resume.
//
// c1 posedges at 10,30,50,...; c2 posedges at 15,35,55,... -- each c2 tick
// falls strictly after the c1 tick that hands off to it.
module main;

  reg c1 = 0, c2 = 0;
  reg a = 1, b = 0;
  reg rst_lo = 0, rst_hi = 1, rst_mid = 0;

  int f_plain = 0, f_lo = 0, f_hi = 0, f_mid = 0;

  // Cover and assert over the identical multiclocked property.
  cv:  cover  property (@(posedge c1) a |=> @(posedge c2) b);            // inst 0
  as:  assert property (@(posedge c1) a |=> @(posedge c2) b) else f_plain++;

  // disable iff, three ways.
  dlo: assert property (@(posedge c1) disable iff (rst_lo)  a |=> @(posedge c2) b) else f_lo++;
  dhi: assert property (@(posedge c1) disable iff (rst_hi)  a |=> @(posedge c2) b) else f_hi++;
  dmid:assert property (@(posedge c1) disable iff (rst_mid) a |=> @(posedge c2) b) else f_mid++;

  always #10 c1 = ~c1;
  initial begin #5 forever #10 c2 = ~c2; end

  int cov_hit = 0;

  initial begin
    // Phase 1, t < 40: b is 0, so every attempt fails. c1@10 and c1@30.
    // rst_mid covers the middle of the run only.
    #40 rst_mid = 1;         // covers c1@50,70 and their c2@55,75
    #40 rst_mid = 0;         // t=80; c1@90 onward runs again
    #30;                     // t=110: c1@90 handed off at c2@95
    b = 1;                   // from here attempts MATCH, so cover counts
    #40;                     // t=150: c1@110,130 match at c2@115,135
    cov_hit = _ivl_sva0_cnt0;

    // 7 c1 ticks reach a handoff by t=150: 10,30,50,70,90,110,130.
    if (f_plain != 5)
      $display("FAILED -- the unguarded control saw %0d failures, expected 5; the test itself is broken",
               f_plain);
    else if (cov_hit != 2)
      $display("FAILED -- multiclocked cover counted %0d matches, expected 2 (b is 1 for the last two attempts)",
               cov_hit);
    else if (f_lo != f_plain)
      $display("FAILED -- disable iff(0)=%0d plain=%0d; a never-asserted disable changed the verdict",
               f_lo, f_plain);
    else if (f_hi != 0)
      $display("FAILED -- disable iff(1) let %0d verdict(s) escape; an aborted attempt must neither pass nor fail",
               f_hi);
    // Outside the reset window and still failing: c1@10, c1@30 (b is 0),
    // and c1@90 -- the reset cleared at t=80 but b does not go high until
    // t=110, so that attempt resumes AND fails. c1@50 and c1@70 are the two
    // the reset swallows, which is what separates this from f_plain's 5.
    else if (f_mid != 3)
      $display("FAILED -- windowed disable saw %0d failures, expected 3 (c1@50 and c1@70 aborted, the other five attempts still judged)",
               f_mid);
    else
      $display("PASSED");

    $finish(0);
  end

endmodule
