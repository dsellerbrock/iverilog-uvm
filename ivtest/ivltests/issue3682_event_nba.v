// IEEE 1800-2017/2023 4.4.2.4, 4.4.2.8, 4.6, 4.9.4 and 9.4.5.
program observer(input logic clk, output bit done);
  int value;
  real r;

  initial begin
    value <= @(posedge clk) 10;
    value <= #1 11;
    r <= @(posedge clk) 3.5;
    @(posedge clk);
    if (value !== 0 || r != 0.0)
      $fatal(1, "program update happened in or before Reactive");
    #0;
    if (value !== 0 || r != 0.0)
      $fatal(1, "program update happened in Re-Inactive");
    @(value);
    if ($time != 1 || value !== 11 || r != 3.5)
      $fatal(1, "program updates did not settle in Re-NBA");
    done = 1;
    #10; // Let the module finish its checks before implicit program exit.
  end
endprogram

module top;
  bit clk, nba_edge;
  wire program_done;
  observer obs(clk, program_done);

  event tick, other;
  int a, rhs = 7, idx = 0, offset = 2, count = 2;
  int ordered, reverse_order, reverse_events, chained;
  bit [7:0] bits, mem [0:1];
  real r, rm [0:1], real_rhs = 1.5, ordered_real;
  real zero, negative, delayed;
  int negative_count = -1, delay_ticks = 2;
  int repeated;

  task check_waiting;
    if (a !== 0 || bits !== 0 || mem[0] !== 0 || mem[1] !== 0 ||
        r != 0.0 || rm[0] != 0.0 || rm[1] != 0.0 ||
        ordered !== 0 || reverse_order !== 0 || reverse_events !== 0 ||
        ordered_real != 0.0 || repeated !== 0)
      $fatal(1, "event-controlled update visible before NBA");
  endtask

  initial begin
    a <= @tick rhs;
    bits[offset+:4] <= @tick 4'hb;
    mem[idx][offset+:4] <= @tick 4'h9;
    r <= @tick real_rhs;
    rm[idx] <= @tick real_rhs;
    repeated <= repeat(count) @tick 7;

    // A timed update can already be queued when the event releases.
    ordered <= @tick 1;
    ordered <= #1 2;
    reverse_order <= #1 1;
    reverse_order <= @tick 2;
    reverse_events <= @other 1;
    reverse_events <= @tick 2;
    ordered_real <= @tick 1.0;
    ordered_real <= #1 2.0;

    rhs = 9; idx = 1; offset = 0; count = 1; real_rhs = 2.5;
    #1;
    clk = 1;
    -> tick;
    -> other;
    check_waiting();
    #0;
    check_waiting();
    #1;
    if (a !== 7 || bits !== 8'h2c || mem[0] !== 8'h24 || mem[1] !== 0 ||
        r != 1.5 || rm[0] != 1.5 || rm[1] != 0.0 || repeated !== 0)
      $fatal(1, "wrong captured RHS, destination or repeat count");
    if (ordered !== 2 || reverse_order !== 2 || reverse_events !== 2 ||
        ordered_real != 2.0)
      $fatal(1, "same-round assignments ran out of statement order");

    // The second tick releases the repeat. An NBA-generated edge releases
    // a separate update, which can only run in the next NBA round.
    -> tick;
    chained <= @(posedge nba_edge) 11;
    nba_edge <= 1;
    chained <= 3;
    @(posedge nba_edge);
    if (chained !== 3 || repeated !== 7)
      $fatal(1, "wrong NBA round for the edge-controlled update");
    #0;
    if (chained !== 3)
      $fatal(1, "chained update visible before the next NBA round");

    zero <= repeat(0) @tick 4.5;
    negative <= repeat(negative_count) @tick 5.5;
    delayed <= #(delay_ticks) 1.0;
    delayed <= #1 2.0;
    #0;
    if (zero != 0.0 || negative != 0.0)
      $fatal(1, "nonpositive repeats wrote before NBA");
    @(chained);
    if ($time != 2 || chained !== 11)
      $fatal(1, "next NBA round did not update in the same slot");
    #1;
    #0;
    if (zero != 4.5 || negative != 5.5 || delayed != 0.0 || program_done !== 1)
      $fatal(1, "wrong settled values or premature timed real update");
    #1;
    #0;
    if (delayed != 2.0)
      $fatal(1, "first timed real NBA missing or second applied early");
    #1;
    if (delayed != 1.0)
      $fatal(1, "later-due real NBA was lost");
    $display("PASS");
    $finish(0);
  end

  initial begin
    #10;
    $fatal(1, "event-controlled NBA did not complete");
  end
endmodule
