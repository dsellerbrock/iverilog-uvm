// IEEE 1800-2017/2023 16.12: a disable iff condition, when true, only
// suppresses the pass/fail JUDGMENT of the property evaluation attempt
// it covers -- "A disabled evaluation of a property does not result in
// success or failure." It says nothing about suspending sampled-value
// functions. $past() (16.9.3, "the sampled value of expression1 in a
// particular time step strictly prior to the one in which $past is
// evaluated") is a separate, unconditional per-clock sampling mechanism:
// it must keep tracking its argument's value every clock tick, including
// ticks where an assertion's own disable iff condition holds, so that a
// LATER (non-disabled) tick's $past() correctly reports the value from
// the disabled tick, not some stale or skipped value.
//
// This is a positive, defensive regression (found no defect -- verified
// correct by careful manual trace during 2026-09-16 SVA investigation)
// guarding both properties together: it is easy to imagine a scheduling
// change that inadvertently ties $past's sampling to whether an
// assertion attempt fired/was disabled, since they share the same
// clocking event and are commonly used together (a disable iff'd
// assertion whose body also references $past on the same signal, per
// OpenTitan-style report-catcher/scoreboard checkers).
module main;
  bit clk = 0;
  bit rst = 0;
  int a = 0;
  int errors = 0;

  always #5 clk = ~clk;

  // Trivially-false body so a PASS can only happen via disable, isolating
  // disable-iff's own pass/fail suppression from any $past question.
  property p_disabled_when_rst;
    @(posedge clk) disable iff (rst) (a != a);
  endproperty
  ap_disable: assert property(p_disabled_when_rst) else errors++;

  int past_at_tick2, past_at_tick3;

  always @(posedge clk) begin
    if ($time == 15) past_at_tick2 = $past(a);
    if ($time == 25) past_at_tick3 = $past(a);
  end

  initial begin
    a = 1;
    @(posedge clk); #1;           // tick1 (t=5): rst=0 -- must fail (not disabled)
    if (errors != 1) begin
      $display("FAIL: tick1 disable-iff suppression state wrong, errors=%0d (expected 1)", errors);
      $finish;
    end

    rst = 1;
    a = 100;
    @(posedge clk); #1;           // tick2 (t=15): rst=1 -- must NOT add a new failure
    if (errors != 1) begin
      $display("FAIL: tick2 should have been disabled (no new failure), errors=%0d (expected 1)", errors);
      $finish;
    end

    rst = 0;
    a = 4;
    @(posedge clk); #1;           // tick3 (t=25): rst=0 again -- must fail again
    if (errors != 2) begin
      $display("FAIL: tick3 disable-iff suppression state wrong, errors=%0d (expected 2)", errors);
      $finish;
    end

    // $past(a) sampled AT tick2 (while disabled) must be tick1's a == 1.
    if (past_at_tick2 !== 1) begin
      $display("FAIL: $past(a) at disabled tick2 = %0d, expected 1 (tick1's value)", past_at_tick2);
      $finish;
    end
    // $past(a) sampled AT tick3 must be tick2's a == 100 -- proving
    // sampling proceeded through the disabled tick, not skipped/stale.
    if (past_at_tick3 !== 100) begin
      $display("FAIL: $past(a) at tick3 = %0d, expected 100 (tick2's value, sampled while disabled)", past_at_tick3);
      $finish;
    end

    $display("PASSED");
    $finish;
  end
endmodule
