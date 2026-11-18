module issue708_sequence_event;
  logic clk = 0, gate = 0, masked = 0;
  event pulse;
  int positional_hits, default_hits, named_hits, guarded_hits, data_hits, pulse_hits;
  int outer_hits, local_hits, child_hits, override_hits, any_edge_hits, leading_hits;
  always #5 clk = !clk;

  sequence positional(event ev);
    @(ev) $time == 15;
  endsequence

  sequence with_default(event ev = posedge clk);
    @(ev) 1'b1;
  endsequence : with_default

  sequence data_clock(bit sig);
    int ready = 2;
    @(posedge sig) (ready == 2) ##1 1'b1;
  endsequence : data_clock

  cover property (positional(posedge clk)) begin
    if ($time != 15) $fatal(1, "positional event at %0t", $time);
    positional_hits++;
  end
  cover property (with_default(.ev())) begin
    if ($time != 5 + 10 * default_hits) $fatal(1, "default event at %0t", $time);
    default_hits++;
  end
  cover property (with_default(.ev(negedge clk))) begin
    if ($time != 10 + 10 * named_hits) $fatal(1, "named event at %0t", $time);
    named_hits++;
  end
  cover property (@(negedge clk) with_default()) begin
    if ($time != 5 + 10 * leading_hits) $fatal(1, "leading clock at %0t", $time);
    leading_hits++;
  end
  cover property (disable iff (masked) with_default(posedge clk iff gate)) begin
    if ($time != 15) $fatal(1, "guarded event at %0t", $time);
    guarded_hits++;
  end
  cover property (data_clock(clk)) begin
    if ($time != 15 + 10 * data_hits) $fatal(1, "data clock at %0t", $time);
    data_hits++;
  end
  cover property (with_default(pulse)) begin
    if ($time != 12 + 10 * pulse_hits) $fatal(1, "named event variable at %0t", $time);
    pulse_hits++;
  end
  cover property (with_default(.ev(clk iff gate))) begin
    if ($time != 10 && $time != 15 && $time != 25)
      $fatal(1, "guarded change at %0t", $time);
    any_edge_hits++;
  end

  // The forward declaration follows a caller that shadows its clock.
  if (1) begin : caller
    bit clk;
    initial #4 clk = 1;
    cover property (forward_clock()) begin
      if ($time != 5 + 10 * outer_hits) $fatal(1, "outer clock at %0t", $time);
      outer_hits++;
    end
    cover property (forward_clock(posedge clk)) begin
      if ($time != 4) $fatal(1, "caller clock at %0t", $time);
      local_hits++;
    end
  end
  sequence forward_clock(event ev = posedge clk);
    @(ev) 1'b1;
  endsequence

  issue708_sequence_event_child child();
  cover property (child.with_default()) begin
    if ($time != 3) $fatal(1, "child default clock at %0t", $time);
    child_hits++;
  end
  cover property (child.with_default(posedge clk)) begin
    if ($time != 5 + 10 * override_hits) $fatal(1, "child override at %0t", $time);
    override_hits++;
  end

  initial begin
    #7 gate = 1;
    #5 -> pulse;
    #5 gate = 0;
    #5;
    -> pulse;
    gate = 1;
    masked = 1;
    #5;
    if (positional_hits != 1 || default_hits != 3 || named_hits != 2 ||
        guarded_hits != 1 || data_hits != 2 || pulse_hits != 2)
      $fatal(1, "hit counts %0d %0d %0d %0d %0d %0d", positional_hits,
             default_hits, named_hits, guarded_hits, data_hits, pulse_hits);
    if (outer_hits != 3 || local_hits != 1 || child_hits != 1 ||
        override_hits != 3 || any_edge_hits != 3 || leading_hits != 3)
      $fatal(1, "scope and clock counts %0d %0d %0d %0d %0d %0d", outer_hits,
             local_hits, child_hits, override_hits, any_edge_hits, leading_hits);
    $display("PASSED");
    $finish(0);
  end
endmodule

module issue708_sequence_event_child;
  bit clk;
  initial #3 clk = 1;
  sequence with_default(event ev = posedge clk);
    @(ev) 1'b1;
  endsequence
endmodule
