// M11-2: transition bins (19.5.3) — sequences of sampled values with
// per-instance NFA progress state. Pre-M11 these parsed and were
// silently dropped.
module m11_coverage_trans_test;

  int pass_count = 0;
  int fail_count = 0;

  task check(input string name, input bit ok);
    if (ok) pass_count++;
    else begin
      fail_count++;
      $display("FAIL: %s", name);
    end
  endtask

  class c;
    int val;
    covergroup cg;
      cp: coverpoint val {
        bins up   = (1 => 2);
        bins ramp = (1 => 2 => 3);
        bins pair = (5 => 6), (7 => 8);   // two sequences, one bin
        bins rng  = ([10:12] => 20);      // range step
      }
    endgroup
    function new(); cg = new; endfunction
    function void go(int v); val = v; cg.sample(); endfunction
    function real cov(); return cg.get_inst_coverage(); endfunction
  endclass

  c o;
  real r;

  initial begin
    // 4 countable bins.
    o = new;
    o.go(1);
    r = o.cov();
    check("no_trans_yet", r == 0.0);

    o.go(2);                       // completes up (1=>2); ramp at pos 2
    r = o.cov();
    check("two_step", r == 25.0);

    o.go(3);                       // completes ramp (1=>2=>3)
    r = o.cov();
    check("three_step", r == 50.0);

    // Broken sequence must NOT count: 1 => 5 => 2
    o = new;
    o.go(1); o.go(5); o.go(2);
    r = o.cov();
    check("broken_seq", r == 0.0);

    // Overlapping restart: 1 => 1 => 2 — the second 1 restarts, up hits
    o = new;
    o.go(1); o.go(1); o.go(2);
    r = o.cov();
    check("restart", r == 25.0);

    // Either sequence satisfies a multi-sequence bin.
    o = new;
    o.go(7); o.go(8);
    r = o.cov();
    check("second_seq", r == 25.0);

    // Range step.
    o = new;
    o.go(11); o.go(20);
    r = o.cov();
    check("range_step", r == 25.0);
    o = new;
    o.go(13); o.go(20);            // 13 outside [10:12]
    r = o.cov();
    check("range_step_miss", r == 0.0);

    if (fail_count == 0)
      $display("M11 COVERAGE TRANS TEST: PASS (%0d/%0d)", pass_count, pass_count);
    else
      $display("M11 COVERAGE TRANS TEST: FAIL (%0d passed, %0d failed)",
               pass_count, fail_count);
    $finish(0);
  end
endmodule
