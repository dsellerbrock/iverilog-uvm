// M9-NFA stage A.2 win: overlapped |-> with a MID-chain window in
// the consequent, and `not` over a mid-chain unbounded delay — the
// legacy engine sorries on both; verdicts checked against a
// hand-computed gold trace.
module overlap_midchain_nfa_only;
  logic clk = 0, a = 0, b = 0, c = 0, d = 0, e = 0, f = 0, g = 0;
  always #5 clk = ~clk;
  // overlap + mid-chain window: legacy sorry
  m1: assert property (@(posedge clk) a |-> b ##[1:2] c ##1 d)
        $display("m1 PASS at %0t", $time);
        else $display("m1 FAIL at %0t", $time);
  // cyclic not: legacy sorry (mid-chain unbounded under not)
  m2: assert property (@(posedge clk) not (e ##[1:$] f ##1 g))
        else $display("m2 FAIL at %0t", $time);
  initial begin
    @(negedge clk) a = 1; b = 1;     // a,b@15; c@25 or c@35
    @(negedge clk) a = 0; b = 0; c = 1;  // c@25; d@35?
    @(negedge clk) c = 0; d = 1;     // d@35: m1 PASS@35
    @(negedge clk) d = 0;
    @(negedge clk) e = 1;            // e@55: not-chain starts
    @(negedge clk) e = 0;
    @(negedge clk) f = 1;            // f@75
    @(negedge clk) f = 0; g = 1;     // g@85: match -> m2 FAIL@85
    @(negedge clk) g = 0;
    @(negedge clk) a = 1; b = 1;     // a,b@105; c@115 or c@125
    @(negedge clk) a = 0; b = 0;
    repeat (2) @(negedge clk);       // no c: m1 FAIL@125
    $finish(0);
  end
endmodule
