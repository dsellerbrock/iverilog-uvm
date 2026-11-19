module issue3825_disabled(input bit clk, output bit woke);
  default disable iff 1'b1;
  sequence s; @(posedge clk) 1'b1; endsequence

  initial begin
    wait (s.triggered);
    woke = ($time == 5 && s.triggered);
  end
endmodule

program issue3825_reactive(input bit clk, output bit saw_endpoint);
  initial begin
    @(posedge clk);
    saw_endpoint = issue3825_sequence_endpoint_observed.endpoint_now();
    #100; // The top module checks the result and ends the simulation.
  end
endprogram

module issue3825_sequence_endpoint_observed;
  bit clk, a = 1, b = 1;
  wire disabled_woke, reactive_seen;
  bit passoff_woke, ranged_woke, nfa_woke, deferred_woke;
  int errors;

  issue3825_disabled disabled_case(clk, disabled_woke);
  issue3825_reactive reactive_reader(clk, reactive_seen);

  sequence s; @(posedge clk) 1'b1; endsequence
  sequence ranged; @(posedge clk) a ##[1:2] b; endsequence
  sequence nfa; @(posedge clk) a ##[1:2] b ##1 1'b1; endsequence
  sequence deferred_clock; 1'b1; endsequence

  function automatic bit endpoint_now();
    return s.triggered;
  endfunction

  initial begin
    $assertpassoff(0);
    #5 clk = 1;
    #5 begin
      clk = 0;
      a = 0; // Only the first edge can start a ranged match.
    end
    repeat (3) begin
      #5 clk = 1;
      #5 clk = 0;
    end
    if (!disabled_woke || !passoff_woke ||
        !reactive_seen || !ranged_woke || !nfa_woke || !deferred_woke || errors)
      $fatal(1, "endpoint checks failed: disable=%b passoff=%b reactive=%b ranged=%b nfa=%b deferred=%b errors=%0d",
             disabled_woke, passoff_woke, reactive_seen, ranged_woke, nfa_woke, deferred_woke, errors);
    $display("PASS sequence endpoint publication");
    $finish(0);
  end

  initial begin
    wait (s.triggered);
    passoff_woke = ($time == 5 && s.triggered);
    #1;
    if (s.triggered) errors++;
  end

  initial begin
    wait (ranged.triggered);
    if ($time != 15 || !ranged.triggered) errors++;
    #1;
    if (ranged.triggered) errors++;
    wait (ranged.triggered);
    ranged_woke = ($time == 25 && ranged.triggered);
  end

  initial begin
    wait (nfa.triggered);
    if ($time != 25 || !nfa.triggered) errors++;
    #1;
    if (nfa.triggered) errors++;
    wait (nfa.triggered);
    nfa_woke = ($time == 35 && nfa.triggered);
  end
  initial begin
    wait (deferred_clock.triggered);
    deferred_woke = ($time == 5 && deferred_clock.triggered);
  end

  default clocking cb @(posedge clk); endclocking
endmodule
