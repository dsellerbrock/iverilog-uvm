`timescale 1ns/1ns

checker seq_monitor(sequence s, output int passes = 0, failures = 0,
                    output time pass_time, fail_time);
  // Same names as the actual's clock and data. This disable belongs here.
  int clk = 0, sample = 0, disabled = 0;

  check_seq: assert property (disable iff (disabled) s)
    begin passes += 1; pass_time = $time; end
    else begin failures += 1; fail_time = $time; end
endchecker

checker event_monitor(event tick, sequence s,
                      output int passes = 0, output time pass_time);
  // The explicit null else must remain distinct from the default action.
  check_event: assert property (@tick s)
    begin passes += 1; pass_time = $time; end
    else ;
endchecker

checker default_monitor(event tick, sequence s = default_seq,
                        output int hits = 0, output time hit_time);
  int accepted = 1;
  sequence default_seq; @tick accepted; endsequence

  check_default: cover property (s)
    begin hits += 1; hit_time = $time; end
endchecker

module issue3863;
  bit clk = 0, sample = 1, tail = 1;
  bit disabled = 1;
  sequence first_stage; sample; endsequence
  sequence delayed; @(posedge clk) first_stage ##1 tail; endsequence
  int pos_passes, pos_failures;
  time pos_pass_time, pos_fail_time;
  seq_monitor positional(delayed, pos_passes, pos_failures,
                         pos_pass_time, pos_fail_time);

  for (genvar i = 2; i < 3; ++i) begin : g
    bit clk = 0, sample = 0;
    sequence first; @(posedge clk) (i == 2 && sample); endsequence
    int passes, failures;
    time pass_time, fail_time;
    seq_monitor named_conn(.s(first), .passes(passes), .failures(failures),
                           .pass_time(pass_time), .fail_time(fail_time));

    initial begin
      #3 sample = 1;
      #4 clk = 1; sample = 0;  // Pass at 7 using the Preponed value.
      #1 clk = 0;
      #4 clk = 1; sample = 1;  // Fail at 12 using the Preponed value.
      #1 clk = 0;
      #4 clk = 1;
    end
  end

  event tick;
  bit value = 1;
  sequence bare_seq; value; endsequence
  int bool_passes, unclocked_passes;
  time bool_time, unclocked_time;
  event_monitor bool_actual(tick, value, bool_passes, bool_time);
  event_monitor unclocked_actual(.tick(tick), .s(bare_seq),
                                 .passes(unclocked_passes), .pass_time(unclocked_time));

  // A default uses the checker declaration, even with a same-named
  // sequence at the connection site.
  sequence default_seq; @tick 1'b0; endsequence
  int default_hits;
  time default_time;
  default_monitor from_default(.tick(tick), .hits(default_hits),
                               .hit_time(default_time));

  sequence s; @(posedge g[2].clk) g[2].sample; endsequence
  int short_passes, short_failures;
  time short_pass_time, short_fail_time;
  seq_monitor shorthand(.s, .passes(short_passes), .failures(short_failures),
                        .pass_time(short_pass_time), .fail_time(short_fail_time));
  if (1) begin : wc
    int passes, failures;
    time pass_time, fail_time;
    seq_monitor wildcard_conn(.*);
  end

  initial begin
    #5 clk = 1;
    #1 clk = 0;
    #4 clk = 1; tail = 0;  // Complete the first match at 10.
    #1 clk = 0;
    #4 clk = 1;  // Fail the second attempt at 15.
  end

  initial begin
    #6 ->tick;
    #3 value = 0;
    #4 ->tick;  // Both explicit null else actions must stay silent.
    #3 $assertoff(0, g[2].named_conn.check_seq);
    #2;
    if (pos_passes !== 1 || pos_pass_time !== 10 ||
        pos_failures !== 1 || pos_fail_time !== 15)
      $fatal(1, "positional verdicts %0d at %0t, %0d at %0t",
             pos_passes, pos_pass_time, pos_failures, pos_fail_time);
    if (g[2].passes !== 1 || g[2].pass_time !== 7 ||
        g[2].failures !== 1 || g[2].fail_time !== 12)
      $fatal(1, "generated named verdicts %0d at %0t, %0d at %0t",
             g[2].passes, g[2].pass_time, g[2].failures, g[2].fail_time);
    if (short_passes !== 2 || short_pass_time !== 17 ||
        short_failures !== 1 || short_fail_time !== 12 ||
        wc.passes !== 2 || wc.pass_time !== 17 ||
        wc.failures !== 1 || wc.fail_time !== 12)
      $fatal(1, "implicit sequence connections gave wrong verdicts");
    if (bool_passes !== 1 || bool_time !== 6 ||
        unclocked_passes !== 1 || unclocked_time !== 6)
      $fatal(1, "event-formal clock did not reach both actuals");
    if (default_hits !== 2 || default_time !== 13)
      $fatal(1, "default sequence did not use its declaration scope");
    $display("PASSED");
    $finish(0);
  end
endmodule
