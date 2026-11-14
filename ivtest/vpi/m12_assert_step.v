// M12-1 / #1348: per-attempt cbAssertionStepSuccess/StepFailure. IEEE
// 1800-2023 39.4.2: "By default, step callbacks are not enabled on any
// assertions; they are enabled on a per-assertion/per-attempt basis (see
// 39.5.2)". 39.5.2: "By default, stepping is disabled for all assertions."
// The plugin enables each attempt from its cbAssertionStart (SVA Q7); a
// step is one tick of one attempt, with its boolean and states (0 origin,
// 1 accepting). `a ##1 b ##1 c`, a true at 5, b at 15, c never:
//   t=5  A5 matches a                -> STEP_OK 0->2
//   t=15 A15 fails a at its first step -> STEP_FAIL 0->2 + FAILURE
//        A5 matches b                -> STEP_OK 2->3
//   t=25 A25 fails a; A5 fails c     -> STEP_FAIL (3->1 for A5) + FAILUREs
// The steps come from the Observed region, where the verdict is
// computed, so they precede the same tick's Reactive-region failure
// reports.
// A plain sequence reports a failure for an attempt that dies at its
// FIRST step, so its attemptStartTime is the failing tick itself
// rather than a latency-recovered launch (implications, where an
// unobligated attempt dies silently, still recover it exactly).
module top;
  bit clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;

  assert property (@(posedge clk) a ##1 b ##1 c);

  initial begin
    #1 $m12as_setup;
    a = 1; #8 a = 0; b = 1; #10 b = 0;
    #20 $finish(0);
  end
endmodule
