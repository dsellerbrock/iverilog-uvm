// M12B-rest: cbAssertionStart fires once per sampled attempt tick;
// $assertoff/$asserton transitions fire Disable/Enable; $assertkill
// fires Reset (plus Disable when it also turns reporting off).
// 5 posedges while enabled -> 5 starts (ticks 1,2 enabled; off before
// tick 3 -> tick 3 disabled reports no start... wait: Start reports are
// emitted by the checker regardless of the REPORTING enable gate; the
// enable gate only mutes fail actions. So all 5 ticks start attempts.
module top;
  logic clk = 0, sig = 1;
  always #5 clk = ~clk;

  a1: assert property (@(posedge clk) sig) else begin end

  initial #1 $setup_assert_cb2;

  initial begin
    @(posedge clk); #1;      // tick 1: start
    @(posedge clk); #1;      // tick 2: start
    $assertoff;              // -> disable (transition)
    @(posedge clk); #1;      // tick 3: start (reporting muted, attempt still runs)
    $asserton;               // -> enable (transition)
    $asserton;               // no transition, no report
    @(posedge clk); #1;      // tick 4: start
    $assertkill;             // -> disable + reset
    @(posedge clk); #1;      // tick 5: start
    #2 $check_assert_cb2(5, 2, 1, 1);
    $finish;
  end
endmodule
