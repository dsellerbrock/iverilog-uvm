// M6B-4, racy form. Two processes drive the clock and the operand, so
// Active-region ordering between them is unspecified -- which is exactly
// why IEEE 1800-2017 16.5.1 samples in the Preponed region: the verdict
// must not depend on that order.
//
// posedges land at 5, 15 and 25; `a' is 1 from t=5 to t=15.
//   t=5  preponed a = 0  -> vacuous
//   t=15 preponed a = 1, b = 0 -> a genuine failure
//   t=25 preponed a = 0  -> vacuous
// so exactly one failure, at t=15, is the CORRECT answer.
//
// (An earlier revision of this probe asserted fails==0 and called any
// other result a preponed bug. That was wrong -- the t=15 failure is
// real -- and the probe passed and failed identically before and after
// the fix, so it never discriminated. m6b4_det is the discriminator;
// this one now checks the count and the failure TIME.)
module top;
  bit clk = 0, a = 0, b = 0;
  int fails = 0, passes = 0;
  int fail_time = -1;
  always #5 clk = ~clk;
  initial begin
    #5 a = 1;
       b = 0;
    #10 a = 0;
    #20;
    if (fails == 1 && passes == 0 && fail_time == 15)
      $display("PASS m6b4_sample (one failure, at t=15)");
    else
      $display("FAIL m6b4_sample fails=%0d passes=%0d fail_time=%0d (expect 1/0/15)",
               fails, passes, fail_time);
    $finish(0);
  end
  ap: assert property (@(posedge clk) a |-> b)
        passes++;
      else begin fails++; if (fail_time < 0) fail_time = $time; end
endmodule
