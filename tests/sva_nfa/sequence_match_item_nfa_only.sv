// IEEE 1800-2017 16.11: a successful sequence step executes its match-item
// subroutine calls in source order. The optional local assignment precedes
// those calls, including on the same step, and action arguments use sampled
// assertion values rather than the Reactive-region design value.
module sequence_match_item_nfa_only;
  logic clk = 0;
  logic cap = 0, done = 0, ord = 0;
  int cap_data = 0, ord_data = 0;

  always #5 clk = ~clk;

  // These NBAs distinguish a sampled action argument from a live Reactive
  // read. Each successful same-step call must print the value from before the
  // edge, not the value installed by this NBA.
  always @(posedge clk) begin
    if (cap) cap_data <= cap_data + 100;
    if (ord) ord_data <= ord_data + 100;
  end

  sequence delayed_capture;
    int x;
    @(posedge clk)
      (cap, x = cap_data) ##2
      (done,
       $display("capture-1 x=%0d", x),
       $display("capture-2 x=%0d", x + 1));
  endsequence

  sequence same_step_order;
    int y;
    @(posedge clk)
      (ord, y = ord_data,
       $display("ordered-1 y=%0d", y),
       $display("ordered-2 y=%0d", y + 1));
  endsequence

  // Failures are intentionally silent: this regression observes only the
  // sequence match actions, once for each successful attempt.
  a_delayed: assert property (delayed_capture) else ;
  a_ordered: assert property (same_step_order) else ;

  initial begin
    // Two adjacent successful attempts prove multiplicity. Their delayed
    // actions must retain 11/12 even though cap_data changes after capture.
    @(negedge clk);
    cap = 1; cap_data = 11;
    ord = 1; ord_data = 21;
    @(negedge clk);
    cap = 1; cap_data = 12;
    ord = 1; ord_data = 31;
    @(negedge clk);
    cap = 0; cap_data = 91;
    ord = 0; done = 1;
    @(negedge clk);
    cap_data = 92;
    done = 1;
    @(negedge clk);
    done = 0;
    repeat (2) @(negedge clk);
    $finish(0);
  end
endmodule
