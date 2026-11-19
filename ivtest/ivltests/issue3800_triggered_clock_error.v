module issue3800_triggered_clock_error;
  bit clk, enabled, other_gate, data;

  sequence falling(start);
    @(negedge clk) start;
  endsequence
  assert property (@(posedge clk) falling(data).triggered);

  sequence gated(gate, start);
    @(posedge clk iff gate) start;
  endsequence
  assert property (@(posedge clk iff other_gate) gated(enabled, data).triggered);

  sequence rising(start);
    @(posedge clk) start;
  endsequence
  if (1) begin : shadow
    bit clk;
    assert property (@(posedge clk) rising(data).triggered);
  end

  sequence multiclock_source;
    @(posedge clk) data ##1 @(negedge clk) data;
  endsequence
  sequence wrapped(start);
    @(posedge clk) start ##1 multiclock_source;
  endsequence
  assert property (@(posedge clk) wrapped(data).triggered);

  if (1) begin : late_default_shadow
    bit clk;
    sequence local_clock(start);
      @(posedge clk) start;
    endsequence
    assert property (local_clock(data).triggered);
  end
  default clocking cb @(posedge clk); endclocking

  assert property (@(posedge clk) gated(enabled,).triggered);
endmodule
