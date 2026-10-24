module test;
  logic clk = 0;
  logic ov_req = 0, ov_ack = 0;
  logic no_req = 0, no_ack = 0;
  logic seq_a = 0, seq_b = 0;
  logic neg_bad = 0;
  logic sel = 0, then_ok = 0, else_ok = 1;
  int overlap_failures = 0, nonoverlap_failures = 0;
  int not_failures = 0, ifelse_failures = 0, sequence_failures = 0;
  always #5 clk = ~clk;

  property p_overlap(req, ack);
    @(posedge clk) req |-> ack;
  endproperty
  assert property (p_overlap(ov_req, ov_ack)) else overlap_failures++;

  property p_nonoverlap(req, ack);
    @(posedge clk) req |=> ack;
  endproperty
  assert property (p_nonoverlap(no_req, no_ack)) else nonoverlap_failures++;

  sequence s_sequence;
    seq_a ##1 seq_b;
  endsequence
  cover property (@(posedge clk) s_sequence);
  assert property (@(posedge clk) seq_a |-> s_sequence) else sequence_failures++;

  property p_negation;
    @(posedge clk) not (neg_bad);
  endproperty
  assert property (p_negation) else not_failures++;

  property p_ifelse;
    @(posedge clk) if (sel) then_ok else else_ok;
  endproperty
  assert property (p_ifelse) else ifelse_failures++;

  initial begin
    @(negedge clk);
    ov_req = 1; ov_ack = 1;
    seq_a = 1;
    sel = 1; then_ok = 1; else_ok = 0;

    @(negedge clk);
    ov_req = 0; ov_ack = 0;
    seq_a = 0; seq_b = 1;
    no_req = 1; no_ack = 0;
    neg_bad = 1;
    sel = 0; then_ok = 0; else_ok = 1;

    @(negedge clk);
    seq_b = 0;
    no_req = 0; no_ack = 1;
    neg_bad = 0;

    @(negedge clk); no_ack = 0;
    repeat (2) @(negedge clk);
    if (overlap_failures != 0 || nonoverlap_failures != 0 ||
        not_failures != 1 || ifelse_failures != 0 || sequence_failures != 0)
      $fatal(1, "§§16.12 core properties: overlap=%0d nonoverlap=%0d not=%0d ifelse=%0d sequence=%0d",
             overlap_failures, nonoverlap_failures, not_failures,
             ifelse_failures, sequence_failures);
    $display("PASSED: §§16.12.1–16.12.3, 16.12.6–16.12.7 core properties");
    $finish(0);
  end
endmodule
