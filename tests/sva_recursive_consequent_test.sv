module sva_recursive_consequent_test;
  bit clk;
  bit rst_n;
  bit trig_not, trig_always, trig_until, trig_nested, trig_throughout;
  bit b, safe, p, q, mid, done, hold, stop;
  int pass_not, fail_not, fail_always, pass_eventual;
  int pass_until, fail_until, pass_nested, fail_nested;
  int pass_throughout, fail_throughout;

  always #5 clk = ~clk;

  assert property (@(posedge clk) disable iff (!rst_n)
                   trig_not |-> not (b[*2]))
    pass_not++; else fail_not++;

  assert property (@(posedge clk) disable iff (!rst_n)
                   trig_always |-> always safe)
    ; else fail_always++;

  assert property (@(posedge clk) disable iff (!rst_n)
                   trig_always |-> ##[0:$] !safe)
    pass_eventual++; else;

  assert property (@(posedge clk) disable iff (!rst_n)
                   trig_until |=> p until q)
    pass_until++; else fail_until++;

  assert property (@(posedge clk) disable iff (!rst_n)
                   trig_nested |-> mid |=> done)
    pass_nested++; else fail_nested++;

  assert property (@(posedge clk) disable iff (!rst_n)
                   trig_throughout |=> hold throughout stop[->1])
    pass_throughout++; else fail_throughout++;

  task tick;
    @(negedge clk);
  endtask

  initial begin
    rst_n = 0;
    safe = 1;
    hold = 1;
    tick();
    rst_n = 1;

    // not(b[*2]) succeeds because the second consecutive b is absent.
    trig_not = 1; b = 1;
    tick();
    trig_not = 0; b = 0;
    tick();

    // The same negated consequence fails when both copies match.
    trig_not = 1; b = 1;
    tick();
    trig_not = 0; b = 1;
    tick();
    b = 0;

    // always safe remains pending until the later safety violation.
    trig_always = 1;
    tick();
    trig_always = 0;
    tick();
    safe = 0;
    tick();
    safe = 1;

    // A nonoverlapped until starts on the following tick and discharges
    // when q arrives while p is still true.
    trig_until = 1;
    tick();
    trig_until = 0; p = 1; q = 0;
    tick();
    q = 1;
    tick();
    p = 0; q = 0;

    // A second attempt violates until on its first consequent tick.
    trig_until = 1;
    tick();
    trig_until = 0;
    tick();

    // Implication is right associative: trig -> (mid -> ##1 done).
    trig_nested = 1; mid = 1;
    tick();
    trig_nested = 0; mid = 0; done = 1;
    tick();
    done = 0;

    trig_throughout = 1;
    tick();
    trig_throughout = 0; hold = 1; stop = 0;
    tick();
    stop = 1;
    tick();

    if (pass_not != 1 || fail_not != 1 || fail_always != 1 || pass_eventual != 1 ||
        pass_until != 1 || fail_until != 1 ||
        pass_nested != 1 || fail_nested != 0 ||
        pass_throughout != 1 || fail_throughout != 0) begin
      $display("FAIL: recursive consequent counters n=%0d/%0d a=%0d e=%0d u=%0d/%0d i=%0d/%0d t=%0d/%0d",
               pass_not, fail_not, fail_always, pass_eventual,
               pass_until, fail_until, pass_nested, fail_nested,
               pass_throughout, fail_throughout);
      $fatal(1);
    end
    $display("PASS: recursive property consequents");
    $finish;
  end
endmodule
