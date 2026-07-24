// M12-1: cbAssertionStepSuccess / cbAssertionStepFailure delivery.
// The automaton checker now reports, once per clock tick, whether any
// live attempt advanced one step of the sequence (StepSuccess) or died
// mid-sequence (StepFailure). Previously both reasons were accepted by
// vpi_register_assertion_cb but never delivered.
//
// Trace for `a ##1 b ##1 c` with posedges at 5,15,25,... (a true only
// at 5, b true only at 15, c never):
//   t=5  attempt A1 matches a  -> STEP_OK
//   t=15 A1 matches b          -> STEP_OK
//        A2 (started 15) fails a at its first step -> STEP_FAIL+FAILURE
//   t=25 A1 fails c            -> STEP_FAIL+FAILURE
//        (A3 also dies at its first step, same tick: reports aggregate)
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
