module issue708_sequence_event;
  bit clk = 0, x = 1, y = 1;
  bit gate = 0, masked = 0, other = 1;
  event pulse;
  int default_hits, named_hits, guarded_hits, data_hits, pulse_hits;
  int outer_hits, local_hits, child_hits, override_hits, any_edge_hits, leading_hits;
  int list_hits, explicit_hits, inherited_hits;
  always #5 clk = ~clk;

  sequence event_arg_example(event ev);
    @(ev) x ##1 y;
  endsequence
  p2: assert property (event_arg_example(posedge clk))
    $display("PASS %0t", $time);
  else
    $fatal(1, "FAIL %0t", $time);

  sequence with_default(event ev = posedge clk);
    @(ev) 1'b1;
  endsequence : with_default

  sequence inherited_type(event ev = posedge clk, alt = negedge clk);
    @(alt) 1'b1;
  endsequence

  sequence data_clock(bit sig);
    int ready = 2;
    @(posedge sig) (ready == 2) ##1 1'b1;
  endsequence : data_clock

  cover property (with_default(.ev())) begin
    if ($time != 5 + 10 * default_hits) $fatal(1, "default event at %0t", $time);
    default_hits++;
  end
  cover property (with_default(.ev(negedge clk))) begin
    if ($time != 10 + 10 * named_hits) $fatal(1, "named event at %0t", $time);
    named_hits++;
  end
  cover property (inherited_type()) begin
    if ($time != 10 + 10 * inherited_hits) $fatal(1, "inherited event type at %0t", $time);
    inherited_hits++;
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
  cover property (with_default(.ev(posedge clk iff gate or negedge other))) begin
    if ($time != 12 && $time != 15 && $time != 25) $fatal(1, "event list at %0t", $time);
    list_hits++;
  end
  cover property (@(posedge clk iff gate or negedge other) 1'b1) begin
    if ($time != 12 && $time != 15 && $time != 25) $fatal(1, "explicit event list at %0t", $time);
    explicit_hits++;
  end

  // The declaration follows a caller that shadows both event operands.
  if (1) begin : caller
    bit clk, gate = 1;
    initial #4 clk = 1;
    cover property (forward_clock()) begin
      if ($time != 15 && $time != 25) $fatal(1, "declaration clock at %0t", $time);
      outer_hits++;
    end
    cover property (forward_clock(posedge clk iff gate)) begin
      if ($time != 4) $fatal(1, "caller clock at %0t", $time);
      local_hits++;
    end
  end
  sequence forward_clock(event ev = posedge clk iff gate);
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
    #5;
    -> pulse;
    other = 0;
    #5 gate = 0;
    #5;
    -> pulse;
    gate = 1;
    masked = 1;
    #5 gate = 0;
    if (default_hits != 3 || named_hits != 2 || guarded_hits != 1 ||
        data_hits != 2 || pulse_hits != 2 || inherited_hits != 2)
      $fatal(1, "hit counts %0d %0d %0d %0d %0d %0d", default_hits,
             named_hits, guarded_hits, data_hits, pulse_hits, inherited_hits);
    if (outer_hits != 2 || local_hits != 1 || child_hits != 1 ||
        override_hits != 3 || any_edge_hits != 3 || leading_hits != 3)
      $fatal(1, "scope and clock counts %0d %0d %0d %0d %0d %0d", outer_hits,
             local_hits, child_hits, override_hits, any_edge_hits, leading_hits);
    if (list_hits != 3 || explicit_hits != list_hits)
      $fatal(1, "event list counts %0d %0d", list_hits, explicit_hits);
    #23;
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
