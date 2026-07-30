// C5-1 (C4-2): $sampled inside a property boolean must read the
// Preponed sample (IEEE 1800-2017 16.9.3 — identical in definition to
// the sample every other assertion operand gets). Pre-fix, $sampled
// was missing from the sva_rewrite_sampled_ dispatch, so it survived
// to a VPI fallback that reads the LIVE value at whatever moment the
// checker evaluates — correct only by scheduling accident. The fix
// rewrites $sampled to the Preponed capture register, making the
// pre-edge read deterministic. x updates via an NBA at the same edge,
// so a post-NBA live read would be one ahead of the oracle (10 + k).
//
// The same call OUTSIDE a property (plain procedural code below)
// cannot use a capture and falls back to the live-value VPI stub;
// that path must be LOUD — the warn-once notice it prints, and the
// deterministic live value (x already incremented once by t=12), are
// part of this test's pinned verdict stream on both engines.
module sampled_preponed;
  logic clk = 0;
  int x = 10, k = 0;
  int good = 0, bad = 0;
  always #5 clk = ~clk;
  always @(posedge clk) x <= x + 1;
  always @(posedge clk) k <= k + 1;

  // At tick k the Preponed sample of x must be exactly 10 + k.
  ap: assert property (@(posedge clk) $sampled(x) == 10 + k)
        good++;
        else bad++;

  initial begin
    #12 $display("procedural live: %0d (expect 11)", $sampled(x));
    repeat (6) @(negedge clk);
    $display("sampled: good=%0d bad=%0d (expect 7/0)", good, bad);
    $finish(0);
  end
endmodule
