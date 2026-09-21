module fixed_long_antecedent_runtime;
  bit clk, rst, a, b, x, y, u, v;
  int pass138, fail138, pass257, fail257, pass1, fail1;
  int base138, base257;

  assert property (@(posedge clk) disable iff (rst)
                   a[*138] |=> b)
    pass138++;
  else
    fail138++;

  assert property (@(posedge clk) disable iff (rst)
                   x[*257] |=> y)
    pass257++;
  else
    fail257++;

  // Protect the original one-step implication/vacuity path.
  assert property (@(posedge clk) disable iff (rst) u |=> v)
    pass1++;
  else
    fail1++;

  // The patch also routes long fixed cover antecedents through the same
  // age pipeline, without an assertion vacuity counter.
  cover property (@(posedge clk) disable iff (rst) a[*138] |=> b);

  task tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  task abort_attempts;
    rst = 1;
    tick();
    rst = 0;
  endtask

  initial begin
    rst = 1;
    a = 0; b = 0; x = 0; y = 0; u = 0; v = 0;
    repeat (2) tick();
    rst = 0;

    // Default assertion control executes pass actions for vacuous and
    // nonvacuous success: tick 2 produces one of each.
    u = 1; v = 0;
    tick();
    u = 0; v = 1;
    tick();
    if (pass1 != 2 || fail1 != 0)
      $fatal(1, "one-step implication mismatch pass=%0d fail=%0d",
             pass1, fail1);

    abort_attempts();
    base138 = pass138;

    // Starts 1..7 mature at consequence ticks 139..145. This exact count
    // proves that overlapping attempts are retained and each endpoint fires.
    a = 1; b = 1;
    repeat (145) tick();
    if (pass138 - base138 != 7 || fail138 != 0)
      $fatal(1, "138-cycle good/overlap mismatch delta=%0d fail=%0d",
             pass138 - base138, fail138);
    $check_long_cover(7);

    // Abort before changing the consequent, then run fewer than 138 samples.
    // The pre-reset prefix must not combine with the post-reset prefix.
    abort_attempts();
    b = 0;
    repeat (100) tick();
    if (pass138 - base138 != 7 || fail138 != 0)
      $fatal(1, "disable iff did not abort 138-cycle attempts delta=%0d fail=%0d",
             pass138 - base138, fail138);
    $check_long_cover(7);

    // Isolate a fresh phase. The same seven endpoints now observe false b.
    abort_attempts();
    repeat (145) tick();
    if (pass138 - base138 != 7 || fail138 != 7)
      $fatal(1, "138-cycle false consequent mismatch delta=%0d fail=%0d",
             pass138 - base138, fail138);
    $check_long_cover(7);

    // Starts 1..8 mature at consequence ticks 258..265 for repeat 257.
    abort_attempts();
    a = 0; x = 1; y = 1;
    base257 = pass257;
    repeat (265) tick();
    if (pass257 - base257 != 8 || fail257 != 0)
      $fatal(1, "257-cycle good/overlap mismatch delta=%0d fail=%0d",
             pass257 - base257, fail257);
    $display("PASSED p138=%0d f138=%0d p257=%0d f257=%0d p1=%0d f1=%0d",
             pass138, fail138, pass257, fail257, pass1, fail1);
    $finish(0);
  end
endmodule
