// C5-1 (SVA-C2-01): sequence endpoint method `.triggered` composed
// inside a compound boolean expression (IEEE 1800-2017 16.13.6).
// Pre-fix, only a BARE top-level `s.triggered` was rewritten; composed
// forms (`s.triggered && e`, `!s.triggered`) fell through to ordinary
// identifier binding, drew only an "Unable to bind" warning, and the
// assertion silently evaluated X — indistinguishable from a pass.
// The fix rewrites `.triggered`/`.matched` recursively through &&, ||,
// !, comparisons, and ternaries. s1 = a ##1 b matches ending on the
// tick where b samples true, so `.triggered` is true exactly there.
module trig_compound;
  logic clk = 0, a = 0, b = 0, e = 0, f = 0;
  always #5 clk = ~clk;

  sequence s1; a ##1 b; endsequence

  // hit: e true on the tick the s1 match ends (T2)
  cv1: cover property (@(posedge clk) s1.triggered && e);
  // miss control: f is never true when a match ends
  cv2: cover property (@(posedge clk) s1.triggered && f);
  // negation compose: true when e is sampled true and NO match ends
  cv3: cover property (@(posedge clk) !s1.triggered && e);

  initial begin
    @(negedge clk) a = 1;              // a sampled at T1
    @(negedge clk) a = 0; b = 1; e = 1; // T2: match ends, e true -> cv1
    @(negedge clk) b = 0; e = 0;
    @(negedge clk) e = 1; f = 0;        // e true, no match end -> cv3
    @(negedge clk) e = 0;
    repeat (3) @(negedge clk);
    $display("cv1=%0d (exp 1) cv2=%0d (exp 0) cv3=%0d (exp 1)",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0, _ivl_sva2_cnt0);
    $finish(0);
  end
endmodule
