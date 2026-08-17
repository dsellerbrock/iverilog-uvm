// M12B-rest: cbAssertionStart fires once per sampled attempt tick;
// $assertoff/$asserton transitions fire Disable/Enable; $assertkill
// fires Reset (plus Disable when it also turns reporting off).
// Three posedges while enabled -> three starts (ticks 1,2 and 4).
// IEEE 1800-2023 20.11 says Off starts no new attempts, while Kill also
// aborts attempts already executing. Active-attempt semantics are pinned by
// the sv_assertkill_* runtime regressions; this test pins the VPI callbacks.
module top;
  logic clk = 0, sig = 1;
  always #5 clk = ~clk;

  a1: assert property (@(posedge clk) sig) else begin end

  initial #1 $setup_assert_cb2;

  initial begin
    @(posedge clk); #1;      // tick 1: start
    @(posedge clk); #1;      // tick 2: start
    $assertoff(0, top.a1);   // -> per-assertion disable (transition)
    @(posedge clk); #1;      // tick 3: no new attempt
    $asserton(0, top.a1);    // -> per-assertion enable (transition)
    $asserton(0, top.a1);    // no transition, no report
    @(posedge clk); #1;      // tick 4: start
    $assertkill(0, top.a1);  // -> per-assertion disable + reset
    @(posedge clk); #1;      // tick 5: no new attempt
    #2 $check_assert_cb2(3, 2, 1, 1);
    $finish;
  end
endmodule
