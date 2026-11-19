module issue3813_nexttime_actions;
  bit clk = 0;
  always #5 clk = ~clk;

  int clock_passes = 0, zero_passes = 0;
  int delay_starts = 0, delay_ends = 0;
  int sampled_passes = 0, sampled_fails = 0;
  int negated_passes = 0, negated_fails = 0;
  int weak_passes = 0, muted_weak_passes = 0;
  int strong_passes = 0, muted_strong_passes = 0;
  int strong_fails = 0, muted_strong_fails = 0;
  int finish_zero = 0;
  bit finish_nba, disable_pulse;
  logic [7:0] operand = 8'h80;
  int tick = 0;

  // The checker must see the preponed value even when the NBA changes it.
  always @(posedge clk) begin
    tick++;
    case (tick)
      3: operand <= 8'b0000000x;
      4: operand <= 8'b0000000z;
      5: operand <= '0;
    endcase
  end

  clock_next: assert property (@(posedge clk) nexttime 1'b1)
    clock_passes++;
  zero: assert property (@(posedge clk) s_nexttime[0] 8'h80)
    zero_passes++;
  delayed: assert property (@(posedge clk) s_nexttime 1'b1) begin
    delay_starts++;
    #12 delay_ends++;
  end
  sampled_next: assert property (@(posedge clk) nexttime[2] operand)
    sampled_passes++; else sampled_fails++;
  negated_next: assert property (@(posedge clk) nexttime[2] not(operand))
    negated_passes++; else negated_fails++;

  weak_finish: assert property (@(posedge clk) nexttime[3] 1'b1)
    weak_passes++;
  muted_weak_finish: assert property (@(posedge clk) nexttime[3] 1'b1)
    muted_weak_passes++;
  strong_finish: assert property (@(posedge clk) s_nexttime[3] 1'b1)
    strong_passes++; else begin
      if ($time != 49) $fatal(1, "failure before finish");
      strong_fails++;
      #0 finish_zero++;
      finish_nba <= 1;
      #1 $fatal(1, "finish drain advanced time");
    end
  muted_strong_finish: assert property (@(posedge clk) s_nexttime[3] 1'b1)
    muted_strong_passes++; else muted_strong_fails++;

  killed: assert property (@(posedge clk) s_nexttime[3] 1'b0)
    else $fatal(1, "killed attempt reported");
  disabled: assert property (@(posedge clk)
                            disable iff (disable_pulse) s_nexttime[2] 1'b0)
    else $fatal(1, "disabled attempt reported");
  muted_fail: assert property (@(posedge clk) s_nexttime[3] 1'b0)
    else $fatal(1, "failure action ran with FailOff");

  initial begin
    #6;
    if (clock_passes != 0 || delay_starts != 0 || zero_passes != 1 ||
        sampled_passes != 0 || sampled_fails != 0)
      $fatal(1, "wrong first-tick verdicts");
    $assertpassoff(0, issue3813_nexttime_actions.zero);
    $assertfailoff(0, issue3813_nexttime_actions.muted_fail);
    $assertkill(0, issue3813_nexttime_actions.killed);
    $assertoff(0, issue3813_nexttime_actions.disabled);
    #1 disable_pulse = 1;
    #1 disable_pulse = 0;

    #8;
    if (clock_passes != 1 || delay_starts != 1 || zero_passes != 1 ||
        sampled_passes != 0 || sampled_fails != 0)
      $fatal(1, "wrong second-tick verdicts");
    $assertoff(0, issue3813_nexttime_actions.clock_next,
                  issue3813_nexttime_actions.delayed);
    $assertpasson(0, issue3813_nexttime_actions.zero);
    $assertvacuousoff(0, issue3813_nexttime_actions.muted_weak_finish,
                         issue3813_nexttime_actions.muted_strong_finish);

    #10;
    if (clock_passes != 2 || delay_starts != 2 || delay_ends != 0 ||
        zero_passes != 2 || sampled_passes != 1 || sampled_fails != 0 ||
        negated_passes != 0 || negated_fails != 1)
      $fatal(1, "older attempts or wide sample failed");
    $assertoff(0, issue3813_nexttime_actions.zero,
                  issue3813_nexttime_actions.sampled_next,
                  issue3813_nexttime_actions.negated_next);

    #10;
    if (sampled_passes != 1 || sampled_fails != 1 || delay_ends != 1 ||
        negated_passes != 1 || negated_fails != 1)
      $fatal(1, "X sample or delayed action failed");
    $asserton(0, issue3813_nexttime_actions.killed,
                 issue3813_nexttime_actions.disabled);

    #10;
    if (sampled_passes != 1 || sampled_fails != 2 || delay_ends != 2 ||
        clock_passes != 2 || delay_starts != 2 || zero_passes != 2 ||
        negated_passes != 2 || negated_fails != 1)
      $fatal(1, "Z sample or Off handling failed");
    if (weak_passes != 2 || muted_weak_passes != 2 ||
        strong_passes != 2 || muted_strong_passes != 2 ||
        strong_fails != 0 || muted_strong_fails != 0)
      $fatal(1, "wrong pre-finish verdict counts");
    // No further clock: Kill/On and a disable pulse must still cancel.
    $assertoff(0, issue3813_nexttime_actions.weak_finish,
                  issue3813_nexttime_actions.strong_finish);
    $assertkill(0, issue3813_nexttime_actions.killed);
    $asserton(0, issue3813_nexttime_actions.killed);
    #1 disable_pulse = 1;
    #1 disable_pulse = 0;
    #1 $finish(0);
  end

  final begin
    if (weak_passes != 5 || muted_weak_passes != 2 ||
        strong_passes != 2 || muted_strong_passes != 2 ||
        strong_fails != 3 || muted_strong_fails != 3 ||
        finish_zero != 3 || !finish_nba)
      $fatal(1, "wrong finish verdicts: weak=%0d/%0d strong fails=%0d/%0d #0=%0d NBA=%b",
             weak_passes, muted_weak_passes, strong_fails, muted_strong_fails,
             finish_zero, finish_nba);
    if (clock_passes != 2 || sampled_passes != 1 || negated_passes != 2 ||
        delay_starts != 2)
      $fatal(1, "Off allowed new attempts");
    assert final (1'b1) $display("PASS");
  end
endmodule
