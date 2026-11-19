`timescale 1ns/1ns
module issue3815_until_cohort;
  bit clk, finish_clk, disable_pulse, finish_pulse;
  logic [127:0] p = 128'h80000000000000000000000000000000;
  logic [127:0] q = '0;
  int weak_passes, strong_passes, weak_fails, strong_fails;
  int weak_with_passes, strong_with_passes, weak_with_fails, strong_with_fails;
  int weak_end_passes, weak_with_end_passes, strong_end_fails, strong_with_end_fails;
  int off_passes, after_kill_passes, after_disable_passes, finish_zero;
  bit finish_nba;

  weak_until: assert property (@(posedge clk) p until q)
    weak_passes++; else weak_fails++;
  strong_until: assert property (@(posedge clk) p s_until q)
    strong_passes++; else strong_fails++;
  weak_with: assert property (@(posedge clk) p until_with q)
    weak_with_passes++; else weak_with_fails++;
  strong_with: assert property (@(posedge clk) p s_until_with q)
    strong_with_passes++; else strong_with_fails++;

  weak_finish: assert property (@(posedge finish_clk) 1'b1 until 1'b0)
    weak_end_passes++; else $fatal(1, "weak until failed at finish");
  weak_with_finish: assert property (@(posedge finish_clk) 1'b1 until_with 1'b0)
    weak_with_end_passes++; else $fatal(1, "weak until_with failed at finish");
  strong_finish: assert property (@(posedge finish_clk) 1'b1 s_until 1'b0)
    $fatal(1, "strong until passed at finish");
  else begin
    strong_end_fails++;
    #0 finish_zero++;
    finish_nba <= 1;
    #1 $fatal(1, "finish action advanced time");
  end
  strong_with_finish: assert property (@(posedge finish_clk) 1'b1 s_until_with 1'b0)
    $fatal(1, "strong until_with passed at finish"); else strong_with_end_fails++;

  off_finish: assert property (@(posedge finish_clk) 1'b1 until 1'b0)
    off_passes++;
  after_kill: assert property (@(posedge finish_clk) 1'b1 until 1'b0)
    after_kill_passes++;
  after_disable: assert property (@(posedge finish_clk) disable iff (disable_pulse)
                                  1'b1 until 1'b0)
    after_disable_passes++;
  killed_at_finish: assert property (@(posedge finish_clk) 1'b1 s_until 1'b0)
    else $fatal(1, "Kill left attempts pending at finish");
  disabled_at_finish: assert property (@(posedge finish_clk) disable iff (finish_pulse)
                                       1'b1 s_until_with 1'b0)
    else $fatal(1, "disable pulse left attempts pending at finish");
  muted_fail: assert property (@(posedge clk) p until_with q)
    else $fatal(1, "FailOff let an action run");

  task automatic tick(input bit both_clocks);
    #5;
    clk = 1;
    finish_clk = both_clocks;
    #1;
    clk = 0;
    finish_clk = 0;
    #1;
  endtask

  task automatic expect_counts(input int plain_pass, plain_fail,
                               with_pass, with_fail);
    if (weak_passes != plain_pass || strong_passes != plain_pass ||
        weak_fails != plain_fail || strong_fails != plain_fail ||
        weak_with_passes != with_pass || strong_with_passes != with_pass ||
        weak_with_fails != with_fail || strong_with_fails != with_fail)
      $fatal(1, "wrong counts at %0t: until %0d/%0d s_until %0d/%0d until_with %0d/%0d s_until_with %0d/%0d",
             $time, weak_passes, weak_fails, strong_passes, strong_fails,
             weak_with_passes, weak_with_fails, strong_with_passes, strong_with_fails);
  endtask

  initial begin
    #1;
`ifdef CHECK_UNTIL_CALLBACKS
    $until_cohort_watch;
`endif
    tick(1);
    expect_counts(0, 0, 0, 0);
    tick(1);
    expect_counts(0, 0, 0, 0);
    $assertoff(0, issue3815_until_cohort.off_finish);
    $assertkill(0, issue3815_until_cohort.after_kill);
    $asserton(0, issue3815_until_cohort.after_kill);
    $assertfailoff(0, issue3815_until_cohort.muted_fail);
    $assertvacuousoff(0, issue3815_until_cohort.weak_finish,
                         issue3815_until_cohort.weak_with_finish);
    disable_pulse = 1;
    #1 disable_pulse = 0;
    p = '0;
    q = 128'h80000000000000000000000000000000;

    // Changing both operands in Active must leave this tick's sample intact.
    #4;
    p = '1;
    q = '0;
    clk = 1;
    finish_clk = 1;
    #1;
    clk = 0;
    finish_clk = 0;
    #1 expect_counts(3, 0, 0, 3);
    $assertkill(0, issue3815_until_cohort.killed_at_finish);
    $asserton(0, issue3815_until_cohort.killed_at_finish);
    finish_pulse = 1;
    #1 finish_pulse = 0;

    p = 'x;
    q = 'z;
    tick(0);
    expect_counts(3, 1, 0, 4);
    p = 'z;
    q = 'x;
    tick(0);
    expect_counts(3, 2, 0, 5);
    p[127] = 1;
    q[127] = 1;
    tick(0);
    expect_counts(4, 2, 1, 5);
    q = 'x;
    tick(0);
    expect_counts(4, 2, 1, 5);
    p = '0;
    q = 'z;
    tick(0);
    expect_counts(4, 4, 1, 7);
    if (weak_end_passes != 0 || weak_with_end_passes != 0 ||
        strong_end_fails != 0 || strong_with_end_fails != 0 ||
        off_passes != 0 || after_kill_passes != 0 || after_disable_passes != 0)
      $fatal(1, "unfinished attempts produced early verdicts");
    $finish(0);
  end

  final begin
    if (weak_end_passes != 3 || weak_with_end_passes != 3 ||
        strong_end_fails != 3 || strong_with_end_fails != 3 ||
        off_passes != 2 || after_kill_passes != 1 || after_disable_passes != 1 ||
        finish_zero != 3 || !finish_nba)
      $fatal(1, "wrong finish counts: weak %0d/%0d strong %0d/%0d Off %0d Kill %0d disable %0d",
             weak_end_passes, weak_with_end_passes, strong_end_fails,
             strong_with_end_fails, off_passes, after_kill_passes, after_disable_passes);
`ifdef CHECK_UNTIL_CALLBACKS
    $until_cohort_check;
`endif
    $display("PASS");
  end
endmodule
