module issue3862;
  bit clk, ok, enabled;
  bit clk_a, clk_b, ok_a, ok_b;
  bit plain_clk;
  int inner_checks, plain_checks;

  issue3862_source a(clk_a, ok_a), b(clk_b, ok_b);

  sequence sampled_ok;
    ok;
  endsequence

  check_a: assert property (a.s)
    $display("a pass %0d", $time);
  else
    $display("a fail %0d", $time);

  check_b: assert property (b.s)
    $display("b pass %0d", $time);
  else
    $display("b fail %0d", $time);

  // A clocked inner declaration shadows the outer plain sequence.
  check_inner: assert property (a.g[1].reverse)
    begin
      if ($time != 9) $fatal(1, "unexpected inner pass at %0d", $time);
      inner_checks++;
    end
  else
    begin
      if ($time != 3) $fatal(1, "unexpected inner failure at %0d", $time);
      inner_checks++;
    end

  // The inner plain sequence still uses the clock of its assertion.
  check_plain: assert property (@(posedge plain_clk) b.g[0].s)
    begin
      if ($time != 12) $fatal(1, "unexpected plain pass at %0d", $time);
      plain_checks++;
    end
  else
    begin
      if ($time != 6) $fatal(1, "unexpected plain failure at %0d", $time);
      plain_checks++;
    end

  initial begin
    #1 ok_a = 1;
    #1 clk = 1;       // Same-spelled caller clock has no assertion to drive.
    #1 clk_a = 1;
    #1 clk_a = 0;
    #1 clk_b = 1;
    #1 plain_clk = 1;
    #1 begin
      clk_b = 0;
      plain_clk = 0;
      ok_a = 0;
      ok_b = 1;
      ok = 1;
    end
    #2 clk_a = 1;
    #2 clk_b = 1;
    #1 plain_clk = 1;
    #1 begin
      if (inner_checks != 2 || plain_checks != 2)
        $fatal(1, "missing scoped checks %0d/%0d", inner_checks, plain_checks);
      if (a.local_passes != 1 || a.local_failures != 1 ||
          b.local_passes != 1 || b.local_failures != 1 ||
          a.local_hier_passes != 1 || a.local_hier_failures != 1 ||
          b.local_hier_passes != 1 || b.local_hier_failures != 1)
        $fatal(1, "missing local sequence checks");
      $finish(0);
    end
  end
endmodule

// Deliberately declared after both hierarchical assertion sites.
package issue3862_pkg;
  parameter bit enabled = 1;
endpackage

module issue3862_source(input clk, ok);
  import issue3862_pkg::enabled;
  int local_passes, local_failures;
  int local_hier_passes, local_hier_failures;

  sequence sampled_ok;
    ok && enabled;
  endsequence

  sequence s;
    @(posedge clk) sampled_ok;
  endsequence

  local_check: assert property (s)
    local_passes++;
  else
    local_failures++;

  sequence reverse;
    1'b0;
  endsequence

  for (genvar n = 0; n < 2; n++) begin : g
    sequence s;
      n == 1 ? !ok : ok;
    endsequence

    sequence reverse;
      @(posedge clk) (s) or (1'b0);
    endsequence
    // This local use consumes the parser's combinator body.
    local_tree: assert property (reverse) ; else ;
  end

  local_hier: assert property (g[1].reverse)
    local_hier_passes++;
  else
    local_hier_failures++;
endmodule
