// M9-NFA stage B.2 win: `intersect` with a windowed operand —
// non-fixed, so the legacy engine sorries ("fixed-length only"); the
// automaton engine builds the product (same-tick lockstep, accept
// only at (accept,accept)). A same-interval match requires the
// windowed side to end at exactly the fixed side's length.
// Verdicts hand-computed into the gold.
module intersect_window_nfa_only;
  logic clk = 0, a = 0, b = 0, c = 0, d = 0;
  always #5 clk = ~clk;

  g1: assert property (@(posedge clk) (a ##1 b) intersect (c ##[1:2] d))
        $display("g1 PASS at %0t", $time);
        else $display("g1 FAIL at %0t", $time);

  initial begin
    @(negedge clk) a = 1; c = 1;                 // both start @15
    @(negedge clk) a = 0; c = 0; b = 1; d = 1;   // both end len2 @25 -> PASS@25
    @(negedge clk) b = 0; d = 0;
    @(negedge clk) a = 1; c = 1;                 // start @45
    @(negedge clk) a = 0; c = 0; b = 1;          // left ends len2 @55; right d=0
    @(negedge clk) b = 0; d = 1;                 // right ends len3 @65 -> no same-interval -> FAIL@55
    repeat (2) @(negedge clk);
    $finish(0);
  end
endmodule
