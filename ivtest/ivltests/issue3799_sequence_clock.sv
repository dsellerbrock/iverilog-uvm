module issue3799_sequence_clock;
  bit clk_a, clk_b, outer_clk, gate_clk;
  bit a, b, enabled, disabled;

  sequence sq(c, x);
    @(posedge c) x;
  endsequence

  check_a: assert property (sq(clk_a, a))
    $display("a pass %0d", $time);
  else
    $display("a fail %0d", $time);

  check_b: assert property (sq(.x(b), .c(clk_b)))
    $display("b pass %0d", $time);
  else
    $display("b fail %0d", $time);

  sequence gated(c, en, x);
    int saved = x;
    @(negedge c iff en) (en && saved == 1);
  endsequence : gated

  // The inner clock overrides the explicit outer event.
  check_gate: assert property (@(posedge outer_clk) disable iff (disabled)
                               gated(gate_clk, enabled, b))
    $display("gate pass %0d", $time);
  else
    $display("gate fail %0d", $time);

  // An equivalent local clock can be used for concatenation.
  int chain_checks = 0;
  same_clock: assert property (@(posedge clk_a) 1'b1 ##1 sq(clk_a, !a))
    begin
      if ($time != 8) $fatal(1, "unexpected chain pass at %0d", $time);
      chain_checks++;
    end
  else
    $fatal(1, "unexpected chain failure at %0d", $time);

  initial begin
    #1 a = 1;
    #1 clk_a = 1;
    #1 clk_a = 0;
    #1 clk_b = 1;
    #1 begin
      clk_b = 0;
      a = 0;
      b = 1;
      enabled = 1;
      gate_clk = 1;
    end
    #1 gate_clk = 0;
    #1 begin
      gate_clk = 1;
      outer_clk = 1;
      disabled = 1;
    end
    #1 clk_a = 1;
    #1 begin
      clk_a = 0;
      gate_clk = 0;
    end
    #1 clk_b = 1;
    #1 begin
      gate_clk = 1;
      disabled = 0;
      enabled = 0;
    end
    #1 gate_clk = 0;
    #1 begin
      gate_clk = 1;
      enabled = 1;
      b = 0;
    end
    #1 gate_clk = 0;
    #1 begin
      if (chain_checks !== 1) $fatal(1, "missing chain verdict");
      $finish(0);
    end
  end
endmodule
