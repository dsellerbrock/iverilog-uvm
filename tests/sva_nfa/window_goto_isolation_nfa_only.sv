// C5-2 wave-3: the window-split ISOLATION property (IEEE 1800-2017
// 16.9.4). `s ##[lo:hi] b[->m]' is the union over arrivals d in
// [lo,hi] and NOTHING ELSE -- an arrival of hi+1 or later is not a
// legal choice, so an occurrence of b that every legal arrival is
// obliged to count may not be skipped.
//
// The first cut of the C5-2 union built every per-arrival fragment
// from the SAME entry state. With lo <= 1 the d=lo fragment's `!e'
// wait self-loop landed on that shared state while the d>=2 fragments
// hung their unguarded delay ticks off it too, so a thread could idle
// on `!e' and THEN take a sibling's delay edge -- realizing unbounded
// arrivals and skipping occurrences. It matched traces the LRM
// forbids, which for an assertion means PASSING where it must FAIL.
//
// Every case below is built so the LEGAL endpoint's continuation is
// FALSE and only a skipped-occurrence endpoint would satisfy it. The
// wave's original tests could not see this: a cover with no
// continuation retires on the earliest (legal) accept, hiding any
// extra later endpoint.
module window_goto_isolation_nfa_only;
  logic clk = 0;
  logic x1 = 0, b1 = 0, c1 = 0;
  logic x2 = 0, b2 = 0, c2 = 0;
  logic x3 = 0, b3 = 0, c3 = 0;
  logic x4 = 0, b4 = 0, c4 = 0;
  logic x5 = 0, b5 = 0, c5 = 0;
  logic x6 = 0, b6 = 0, c6 = 0;
  always #5 clk = ~clk;

  // Stimulus shared shape: x@T, b@T+2 and T+3, c@T+4 only.
  //   d=1: goto starts T+1, b false there, first b = T+2 -> end T+2.
  //   d=2: goto starts T+2, b true            -> end T+2.
  // Endpoint set = {T+2}; `##1 c' checks c@T+3 = 0 -> NO match.
  // Only a skipped b (arrival 3, illegal) reaches c@T+4.
  cv1: cover property (@(posedge clk) x1 ##[1:2] b1[->1] ##1 c1);
  // Same for nonconsecutive: the b at T+3 blocks the [=1] span from
  // extending, so the span cannot be anchored on it either.
  cv2: cover property (@(posedge clk) x2 ##[1:2] b2[=1] ##1 c2);
  // lo = 0 is equally illegal beyond hi.
  cv3: cover property (@(posedge clk) x3 ##[0:2] b3[->1] ##1 c3);
  // Fixed-delay CONTROL, identical stimulus: isolates the window
  // split as the mechanism (this arm never had the defect).
  cv4: cover property (@(posedge clk) x4 ##1 b4[->1] ##1 c4);
  // MUST-MATCH control: same window, but c on the legal endpoint+1.
  // Guards against "fixed by rejecting everything".
  cv5: cover property (@(posedge clk) x5 ##[1:2] b5[->1] ##1 c5);
  // Sharpest control: SAME stimulus, window shifted to [2:3]. Here
  // arrival d=3 is LEGAL, starts the goto at T+3 where b is true, so
  // the endpoint is T+3 and c@T+4 matches. The very tick that is
  // forbidden above (reachable only by skipping an occurrence) is
  // required here -- so a "fix" that merely blocks late endpoints,
  // rather than restoring the arrival bound, fails this case.
  cv6: cover property (@(posedge clk) x6 ##[2:3] b6[->1] ##1 c6);

  int fails = 0, passes = 0;
  // The headline idiom, as an ASSERTION: with the consequent's only
  // legal endpoint at T+2 and done false at T+3, this must FAIL
  // exactly once. Under the defect it silently PASSED.
  ap: assert property (@(posedge clk) x1 |-> ##[1:2] b1[->1] ##1 c1)
        passes++;
        else fails++;

  initial begin
    // T: all antecedents high.
    @(negedge clk) begin
      x1 = 1; x2 = 1; x3 = 1; x4 = 1; x6 = 1;
    end
    // T+1: quiet -- every b false, so the d=lo arm must idle.
    @(negedge clk) begin
      x1 = 0; x2 = 0; x3 = 0; x4 = 0; x6 = 0;
    end
    // T+2: the occurrence every legal arrival must count.
    @(negedge clk) begin
      b1 = 1; b2 = 1; b3 = 1; b4 = 1; b6 = 1;
    end
    // T+3: a SECOND occurrence -- the only tick a skipped-occurrence
    // path could land on. Continuations stay false here.
    @(negedge clk) ;
    // T+4: continuations true -- reachable ONLY from the illegal
    // arrival. Any count here is a match the LRM forbids.
    @(negedge clk) begin
      b1 = 0; b2 = 0; b3 = 0; b4 = 0; b6 = 0;
      c1 = 1; c2 = 1; c3 = 1; c4 = 1; c6 = 1;
    end
    @(negedge clk) begin
      c1 = 0; c2 = 0; c3 = 0; c4 = 0; c6 = 0;
    end
    repeat (3) @(negedge clk);

    // cv5 must-match phase: x5@T', b5@T'+1 (legal d=1 endpoint),
    // c5@T'+2 -> exactly one match.
    @(negedge clk) x5 = 1;
    @(negedge clk) begin x5 = 0; b5 = 1; end
    @(negedge clk) begin b5 = 0; c5 = 1; end
    @(negedge clk) c5 = 0;
    repeat (4) @(negedge clk);

    $display("cv1=%0d (exp 0) cv2=%0d (exp 0) cv3=%0d (exp 0)",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0, _ivl_sva2_cnt0);
    $display("cv4=%0d (exp 0) cv5=%0d (exp 1) cv6=%0d (exp 1)",
             _ivl_sva3_cnt0, _ivl_sva4_cnt0, _ivl_sva5_cnt0);
    $display("ap pass=%0d (exp 0) fail=%0d (exp 1)", passes, fails);
    $finish(0);
  end
endmodule
