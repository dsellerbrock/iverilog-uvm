module issue3827_sequence_disable #(parameter int N = 1) (output bit done);
  bit clk, source_clk, hit, start, sample, reset;
  bit keep = 1;
  logic gate = 1;
  int tick_pass, tick_fail;
  int named_pass, named_fail;
  int ante_pass, ante_fail, cons_pass, cons_fail;

  sequence endpoint;
    @(posedge source_clk) hit;
  endsequence

  // This explicit disable comes from named-property expansion.
  property delayed_check;
    @(posedge clk) disable iff ((endpoint.triggered && gate) || reset)
      start |-> ##3 sample;
  endproperty
  named_check: assert property (delayed_check) named_pass++;
  else named_fail++;

  // These checkers are lowered before the default condition is declared.
  tick_check: assert property (@(posedge clk) sample) tick_pass++;
  else tick_fail++;
  repeat_ante: assert property (@(posedge clk)
    start ##1 keep[*N] |-> ##1 sample) ante_pass++;
  else ante_fail++;
  repeat_cons: assert property (@(posedge clk)
    start |=> keep[*N] ##1 sample) cons_pass++;
  else cons_fail++;

  int expected_tick_pass, expected_tick_fail;
  int expected_pass, expected_fail;

  task tick(input bit sampled_value, endpoint_hit, source_first,
            input int tick_verdict, delayed_verdict,
            input bit set_gate_nba = 0);
    sample = sampled_value;
    hit = endpoint_hit;
    #5;
    if (source_first) begin
      source_clk = 1;
      clk = 1;
    end else begin
      clk = 1;
      source_clk = 1;
    end
    // The property must still read the Preponed sample. The compound
    // disable must see the live gate if it changed on this tick.
    sample <= !sampled_value;
    if (set_gate_nba) gate <= 1;
    #1;
    clk = 0;
    source_clk = 0;

    expected_tick_pass += tick_verdict == 1;
    expected_tick_fail += tick_verdict == -1;
    expected_pass += delayed_verdict == 1;
    expected_fail += delayed_verdict == -1;
    if (tick_pass !== expected_tick_pass || tick_fail !== expected_tick_fail)
      $fatal(1, "tick at %0t expected %0d/%0d, got %0d/%0d",
             $time, expected_tick_pass, expected_tick_fail, tick_pass, tick_fail);
    if (named_pass !== expected_pass || named_fail !== expected_fail ||
        ante_pass !== expected_pass || ante_fail !== expected_fail ||
        cons_pass !== expected_pass || cons_fail !== expected_fail)
      $fatal(1, "delayed at %0t expected %0d/%0d, got named %0d/%0d, ante %0d/%0d, cons %0d/%0d",
             $time, expected_pass, expected_fail, named_pass, named_fail,
             ante_pass, ante_fail, cons_pass, cons_fail);
  endtask

  task launch(input bit endpoint_hit = 0, set_gate_nba = 0);
    start = 1;
    tick(1, endpoint_hit, 0, endpoint_hit ? 0 : 1, 0, set_gate_nba);
    start = 0;
  endtask

  task age_attempt;
    tick(0, 0, 0, -1, 0);
    tick(1, 0, 1, 1, 0);
  endtask

  initial begin
    $assertvacuousoff(0, named_check, repeat_ante, repeat_cons);

    // An endpoint with a gate raised by NBA prevents a new attempt.
    gate = 0;
    launch(1, 1);
    age_attempt();
    tick(0, 0, 0, -1, 0);

    // On the verdict tick, suppress an older failure and an older pass.
    // Reverse the order that the checker and the publisher are woken.
    launch();
    age_attempt();
    tick(0, 1, 0, 0, 0);
    launch();
    age_attempt();
    tick(1, 1, 1, 0, 0);

    // A different clock publishes between property ticks. Only a live
    // asynchronous abort can prevent this attempt's later failure.
    launch();
    hit = 1;
    #2 source_clk = 1;
    #1 source_clk = 0;
    age_attempt();
    tick(0, 0, 1, -1, 0);

    // A fresh attempt succeeds, even when an endpoint is masked.
    launch();
    age_attempt();
    gate = 0;
    tick(1, 1, 1, 1, 1);

    // With an endpoint miss the same checkers deliver an exact failure.
    gate = 1;
    launch();
    age_attempt();
    tick(0, 0, 0, -1, -1);

    // An ordinary reset pulse still cancels an older attempt.
    launch();
    #2 reset = 1;
    #1 reset = 0;
    age_attempt();
    tick(0, 0, 1, -1, 0);

    done = 1;
  end

  default disable iff ((endpoint.triggered && gate) || reset);
endmodule

module issue3827_multiclock_disable(output bit done);
  bit c1, c2, c3, source_clk, hit, good;
  int overlap_pass, overlap_fail;
  int strict_pass, strict_fail;
  int chain_pass, chain_fail;

  sequence endpoint;
    @(posedge source_clk) hit;
  endsequence

  assert property (@(posedge c1) disable iff (endpoint.triggered)
    1'b1 |-> @(posedge c2) good) overlap_pass++;
  else overlap_fail++;
  assert property (@(posedge c1) disable iff (endpoint.triggered)
    1'b1 |=> @(posedge c2) good) strict_pass++;
  else strict_fail++;
  assert property (@(posedge c1) 1'b1 |->
    @(posedge c2) 1'b1 ##0 @(posedge c3) good) chain_pass++;
  else chain_fail++;

  task ticks(input bit lead, second, third, endpoint_hit);
    hit = endpoint_hit;
    #5;
    c3 = third;
    c2 = second;
    c1 = lead;
    source_clk = 1;
    #1;
    c3 = 0;
    c2 = 0;
    c1 = 0;
    source_clk = 0;
  endtask

  task check_counts(input int op, ofail, sp, sf, cp, cf);
    if (overlap_pass !== op || overlap_fail !== ofail ||
        strict_pass !== sp || strict_fail !== sf ||
        chain_pass !== cp || chain_fail !== cf)
      $fatal(1, "multiclock at %0t expected %0d/%0d %0d/%0d %0d/%0d, got %0d/%0d %0d/%0d %0d/%0d",
             $time, op, ofail, sp, sf, cp, cf, overlap_pass, overlap_fail,
             strict_pass, strict_fail, chain_pass, chain_fail);
  endtask

  initial begin
    good = 1;
    ticks(1, 1, 1, 1);
    ticks(0, 1, 1, 0);
    check_counts(0, 0, 0, 0, 0, 0);

    // Overlapped handoffs see a simultaneous edge. The strict handoff
    // requires the following destination edge.
    ticks(1, 1, 1, 0);
    check_counts(1, 0, 0, 0, 1, 0);
    ticks(0, 1, 0, 0);
    check_counts(1, 0, 1, 0, 1, 0);

    good = 0;
    ticks(1, 0, 0, 0);
    ticks(0, 0, 0, 1);
    ticks(0, 1, 1, 0);
    check_counts(1, 0, 1, 0, 1, 0);

    ticks(1, 1, 1, 0);
    check_counts(1, 1, 1, 0, 1, 1);
    ticks(0, 1, 0, 0);
    check_counts(1, 1, 1, 1, 1, 1);
    done = 1;
  end

  default disable iff (endpoint.triggered);
endmodule

module issue3827_sequence_disable_top;
  wire done, multiclock_done;
  issue3827_sequence_disable #(.N(2)) test_case(done);
  issue3827_multiclock_disable multiclock_case(multiclock_done);

  initial begin
    wait (done && multiclock_done);
    $display("PASSED");
    $finish(0);
  end
endmodule
