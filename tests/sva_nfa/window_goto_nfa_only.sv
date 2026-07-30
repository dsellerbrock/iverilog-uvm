// C5-2 (CL1-001): goto/nonconsecutive repetition fed by windowed
// (##[m:n]), unbounded (##[m:$]) and ##0-fused arrivals (IEEE
// 1800-2017 16.9.2/16.9.4). Pre-fix the automaton engine DECLINED
// these shapes at construction and the fallback diagnostic told the
// user to enable the engine that had already declined. Every count
// below is hand-computed from the LRM semantics; each cover uses its
// own signals so phases cannot complete each other's attempts.
//
// Key semantics pinned here:
//  - The window bounds only the delay BEFORE the goto starts; the
//    goto then waits unboundedly (cv1 case b matches with a at
//    offset 3 from a [1:2] window -- arrival at +1, first `a' later).
//  - ##[m:$] excludes occurrences before tick m (cv2 case a).
//  - A ##0-fused goto counts an occurrence on the arrival tick
//    itself (cv3), and a ##0-fused nonconsecutive [=1] span is
//    anchored on the arrival tick, so a second occurrence blocks its
//    trailing extension (cv4 case b).
//  - One successful attempt counts ONCE even when two window splits
//    reach accept on different ticks (cv6; retire on first accept --
//    the count-of-successful-attempts convention).
module window_goto_nfa_only;
  logic clk = 0;
  logic r1 = 0, a1 = 0;
  logic r2 = 0, a2 = 0;
  logic r3 = 0, a3 = 0;
  logic r4 = 0, b4 = 0, c4 = 0;
  logic r5 = 0, a5 = 0, c5 = 0;
  logic r6 = 0, a6 = 0;
  always #5 clk = ~clk;

  cv1: cover property (@(posedge clk) r1 ##[1:2] a1[->1]);
  cv2: cover property (@(posedge clk) r2 ##[2:$] a2[->1]);
  cv3: cover property (@(posedge clk) r3 ##0 a3[->1]);
  cv4: cover property (@(posedge clk) r4 ##0 b4[=1] ##1 c4);
  cv5: cover property (@(posedge clk) r5 ##[1:2] a5[->1] ##1 c5);
  cv6: cover property (@(posedge clk) r6 ##[1:2] a6[->1]);

  initial begin
    // cv1 (a): a at offset 1 -> match ends there.        cnt 0->1
    @(negedge clk) r1 = 1;
    @(negedge clk) r1 = 0; a1 = 1;
    @(negedge clk) a1 = 0;
    // cv1 (b): a at offset 3 -- OUTSIDE the [1:2] window but the
    // goto (started at +1 or +2) waits for it -> match.   cnt 1->2
    @(negedge clk) r1 = 1;
    @(negedge clk) r1 = 0;
    @(negedge clk);
    @(negedge clk) a1 = 1;
    @(negedge clk) a1 = 0;
    // cv1 (c): no a after this pulse -> attempt pends forever, no
    // further count.
    @(negedge clk) r1 = 1;
    @(negedge clk) r1 = 0;

    // cv2 (a): a at offset 3 -> arrival +2 waits one tick. cnt 0->1
    @(negedge clk) r2 = 1;
    @(negedge clk) r2 = 0;
    @(negedge clk);
    @(negedge clk) a2 = 1;
    @(negedge clk) a2 = 0;
    // cv2 (b): a ONLY at offset 1 -- before the [2:$] arrival, so no
    // goto ever sees it, and a never rises again -> NO match (this
    // phase is LAST for cv2 so the pending attempt cannot be
    // completed by later stimulus).                       cnt 1
    @(negedge clk) r2 = 1;
    @(negedge clk) r2 = 0; a2 = 1;
    @(negedge clk) a2 = 0;

    // cv3 (a): a3 true on r3's own tick -> fused occurrence, match
    // ends on the SAME tick.                              cnt 0->1
    @(negedge clk) begin r3 = 1; a3 = 1; end
    @(negedge clk) begin r3 = 0; a3 = 0; end
    // cv3 (b): r3 alone, a3 two ticks later.              cnt 1->2
    @(negedge clk) r3 = 1;
    @(negedge clk) r3 = 0;
    @(negedge clk) a3 = 1;
    @(negedge clk) a3 = 0;

    // cv4 (a): b4 on r4's tick ([=1] fused occurrence), one quiet
    // tick, c4 -> span ends at the occurrence, ##1 lands on a
    // trailing-gap tick... the span extends through the !b gap, so
    // c4 at +2 matches (span end +1, one tick later).     cnt 0->1
    @(negedge clk) begin r4 = 1; b4 = 1; end
    @(negedge clk) begin r4 = 0; b4 = 0; end
    @(negedge clk) c4 = 1;
    @(negedge clk) c4 = 0;
    // cv4 (b): b4 on r4's tick AND the next tick, c4 at +3 only:
    // every span containing exactly one b4 must end on the fused
    // tick (the second b4 blocks extension), so c4 is only checked
    // at +1 -- false -> NO match.
    @(negedge clk) begin r4 = 1; b4 = 1; end
    @(negedge clk) r4 = 0;          // b4 still 1
    @(negedge clk) b4 = 0;
    @(negedge clk) c4 = 1;
    @(negedge clk) c4 = 0;

    // cv5: goto endpoint feeds a continuation. a5 at +1 and +2, c5
    // at +2: the +1-arrival split matches (goto ends +1, c5 at +2);
    // retire on first accept.                             cnt 0->1
    @(negedge clk) r5 = 1;
    @(negedge clk) r5 = 0; a5 = 1;
    @(negedge clk) c5 = 1;          // a5 still 1
    @(negedge clk) begin a5 = 0; c5 = 0; end

    // cv6: multi-endpoint attempt -- a6 true at +1 AND +2, so the
    // two window splits accept on different ticks; ONE attempt,
    // ONE count.                                          cnt 0->1
    @(negedge clk) r6 = 1;
    @(negedge clk) r6 = 0; a6 = 1;
    @(negedge clk);                 // a6 still 1
    @(negedge clk) a6 = 0;

    repeat (3) @(negedge clk);
    $display("cv1=%0d (exp 2) cv2=%0d (exp 1) cv3=%0d (exp 2)",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0, _ivl_sva2_cnt0);
    $display("cv4=%0d (exp 1) cv5=%0d (exp 1) cv6=%0d (exp 1)",
             _ivl_sva3_cnt0, _ivl_sva4_cnt0, _ivl_sva5_cnt0);
    $finish(0);
  end
endmodule
