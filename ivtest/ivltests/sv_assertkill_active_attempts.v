// IEEE 1800-2017 20.12: Off prevents new attempts but preserves attempts
// already executing; Kill aborts executing attempts as well.  The immediate
// Kill/On pairs prove that reset is not represented by the enable bit alone.
module sv_assertkill_active_attempts;
  parameter int REP = 3;

  bit clk;
  bit linear_req, linear_ack;
  bit nfa_a, nfa_b, nfa_c;
  bit repeat_a, repeat_b;
  bit gen_req, gen_ack;
  bit next_p = 1;
  bit always_p = 1;

  int linear_failures;
  int nfa_failures;
  int repeat_failures;
  int genvar_failures;
  int next_failures;
  int always_failures;

  active_linear: assert property (@(posedge clk)
      linear_req |-> ##2 linear_ack)
    else linear_failures++;

  active_nfa: assert property (@(posedge clk)
      nfa_a |-> ##[1:2] nfa_b ##1 nfa_c)
    else nfa_failures++;

  active_repeat: assert property (@(posedge clk)
      repeat_a[*REP] |-> repeat_b)
    else repeat_failures++;

  for (genvar delay = 2; delay <= 2; delay++) begin : G
    active_genvar: assert property (@(posedge clk)
        gen_req |-> ##delay gen_ack)
      else genvar_failures++;
  end

  active_next: assert property (@(posedge clk) nexttime[2] next_p)
    else next_failures++;

  active_bounded_always: assert property (@(posedge clk) always[1:2] always_p)
    else always_failures++;

  task automatic tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    // Off preserves this already-running linear attempt.
    linear_req = 1;
    tick();
    linear_req = 0;
    tick();
    $assertoff(0, sv_assertkill_active_attempts.active_linear);
    tick();
    if (linear_failures != 1)
      $fatal(1, "Off lost active attempt: failures=%0d", linear_failures);
    $asserton(0, sv_assertkill_active_attempts.active_linear);

    // Kill removes the corresponding attempt at the same pipeline age.
    linear_req = 1;
    tick();
    linear_req = 0;
    tick();
    $assertkill(0, sv_assertkill_active_attempts.active_linear);
    $asserton(0, sv_assertkill_active_attempts.active_linear);
    tick();
    if (linear_failures != 1)
      $fatal(1, "Kill retained linear attempt: failures=%0d", linear_failures);

    // A new post-Kill attempt proves that On re-arms the same checker.
    linear_req = 1;
    tick();
    linear_req = 0;
    tick();
    tick();
    if (linear_failures != 2)
      $fatal(1, "linear checker did not re-arm: failures=%0d", linear_failures);

    // Variable endpoint fan-out is handled by the NFA engine.
    nfa_a = 1;
    tick();
    nfa_a = 0;
    nfa_b = 1;
    tick();
    nfa_b = 0;
    $assertkill(0, sv_assertkill_active_attempts.active_nfa);
    $asserton(0, sv_assertkill_active_attempts.active_nfa);
    tick();
    if (nfa_failures != 0)
      $fatal(1, "Kill retained NFA attempt: failures=%0d", nfa_failures);
    nfa_a = 1;
    tick();
    nfa_a = 0;
    nfa_b = 1;
    tick();
    nfa_b = 0;
    tick();
    if (nfa_failures != 1)
      $fatal(1, "NFA checker did not re-arm: failures=%0d", nfa_failures);

    // Instance-resolved repetition has its own compact attempt pipeline.
    repeat_a = 1;
    tick();
    tick();
    $assertkill(0, sv_assertkill_active_attempts.active_repeat);
    $asserton(0, sv_assertkill_active_attempts.active_repeat);
    repeat_a = 0;
    tick();
    if (repeat_failures != 0)
      $fatal(1, "Kill retained repeated attempt: failures=%0d",
             repeat_failures);
    repeat_a = 1;
    tick();
    tick();
    tick();
    repeat_a = 0;
    tick();
    if (repeat_failures != 1)
      $fatal(1, "repeat checker did not re-arm: failures=%0d",
             repeat_failures);

    // The selector must canonicalize G[2], rather than spelling it G['sd2].
    gen_req = 1;
    tick();
    gen_req = 0;
    tick();
    $assertkill(0, sv_assertkill_active_attempts.G[2].active_genvar);
    $asserton(0, sv_assertkill_active_attempts.G[2].active_genvar);
    tick();
    if (genvar_failures != 0)
      $fatal(1, "Kill retained generated attempt: failures=%0d",
             genvar_failures);
    gen_req = 1;
    tick();
    gen_req = 0;
    tick();
    tick();
    if (genvar_failures != 1)
      $fatal(1, "generated checker did not re-arm: failures=%0d",
             genvar_failures);

    // Off shifts no new token into this temporal pipeline, but the token
    // already due must still report its failure.
    tick();
    tick();
    next_p = 0;
    $assertoff(0, sv_assertkill_active_attempts.active_next);
    tick();
    if (next_failures != 1)
      $fatal(1, "Off lost temporal attempt: failures=%0d", next_failures);
    $asserton(0, sv_assertkill_active_attempts.active_next);
    next_p = 1;
    tick();
    tick();

    // The verdict bit is captured before Observed. Kill in the clock slot
    // must clear that derived bit as well as the underlying attempt token.
    next_p = 0;
    fork
      begin
        #1;
        $assertkill(0, sv_assertkill_active_attempts.active_next);
        $asserton(0, sv_assertkill_active_attempts.active_next);
      end
      tick();
    join
    if (next_failures != 1)
      $fatal(1, "Kill retained temporal verdict: failures=%0d",
             next_failures);
    next_p = 1;
    tick();
    tick();
    next_p = 0;
    tick();
    if (next_failures != 2)
      $fatal(1, "temporal checker did not re-arm: failures=%0d",
             next_failures);

    // Finite temporal attempts preserved by Off must expire at the declared
    // upper bound; they must not turn into an unbounded aggregate obligation.
    always_p = 1;
    tick();
    $assertoff(0, sv_assertkill_active_attempts.active_bounded_always);
    tick();
    tick();
    always_p = 0;
    tick();
    if (always_failures != 0)
      $fatal(1, "expired always attempt remained active: failures=%0d",
             always_failures);
    always_p = 1;
    $asserton(0, sv_assertkill_active_attempts.active_bounded_always);
    tick();
    always_p = 0;
    tick();
    if (always_failures != 1)
      $fatal(1, "bounded always checker did not re-arm: failures=%0d",
             always_failures);

    $display("PASSED");
    $finish;
  end
endmodule
