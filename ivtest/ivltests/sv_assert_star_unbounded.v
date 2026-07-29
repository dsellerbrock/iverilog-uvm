// IEEE 1800-2017 16.9.2: unbounded consecutive repetition `e[*m:$]'.
//
// The goto (`[->m:$]') and nonconsecutive (`[=m:$]') forms already had
// their unbounded variants; the plain star form did not, so `a[*1:$]' was
// a syntax error. In the automaton engine the unbounded tail is a guarded
// SELF-LOOP on the join state rather than a finite fan-out of optional
// ticks.
//
// The test proves the repeat actually LOOPS -- it must match after one,
// two and three consecutive occurrences -- and that it still fails when
// the sequence cannot start at all. A parse-only check would pass even if
// the repetition silently matched nothing.
//
// NOTE: `[*m:$]' in an implication ANTECEDENT is a separate, still-open
// limitation (no variable-length antecedent is supported yet), so this
// test exercises the consequent and standalone positions.

module sv_assert_star_unbounded;

  logic clk = 0;
  logic t = 0, a = 0, b = 0;

  int miss = 0;

  always #5 clk = ~clk;

  // After t, `a' must repeat one or more times and then be followed by b.
  Unb_A: assert property (@(posedge clk) t |=> a[*1:$] ##1 b) else miss++;

  int miss_at_1, miss_at_2, miss_at_3;
  int errors = 0;

  task automatic pulse_t();
    @(negedge clk); t = 1; a = 0; b = 0;
    @(negedge clk); t = 0;
  endtask

  task automatic run_len(input int n);
    pulse_t();
    for (int k = 0; k < n; k++) begin
      a = 1; b = 0;
      @(negedge clk);
    end
    a = 0; b = 1;
    @(negedge clk);
    b = 0;
    repeat (3) @(negedge clk);
  endtask

  initial begin
    repeat (2) @(negedge clk);

    // One repetition, then b.
    run_len(1);
    miss_at_1 = miss;
    // Two repetitions, then b.
    run_len(2);
    miss_at_2 = miss;
    // Three repetitions, then b.
    run_len(3);
    miss_at_3 = miss;

    if (miss_at_1 != 0) begin
      $display("FAILED -- a[*1:$] did not match a single occurrence (%0d fails)",
               miss_at_1);
      errors++;
    end
    if (miss_at_2 != miss_at_1) begin
      $display("FAILED -- a[*1:$] did not match two occurrences (fails went %0d -> %0d)",
               miss_at_1, miss_at_2);
      errors++;
    end
    if (miss_at_3 != miss_at_2) begin
      $display("FAILED -- a[*1:$] did not match three occurrences (fails went %0d -> %0d)",
               miss_at_2, miss_at_3);
      errors++;
    end

    // Now a case that must FAIL: t, then no `a' at all, so the
    // consequent cannot even start.
    pulse_t();
    a = 0; b = 0;
    repeat (5) @(negedge clk);

    if (miss == miss_at_3) begin
      $display("FAILED -- the assertion never fired when the sequence could not start");
      errors++;
    end

    if (errors == 0) $display("PASSED");
    $finish(0);
  end

endmodule
