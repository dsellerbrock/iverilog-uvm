// M12-2: s_vpi_attempt_info.attemptStartTime recovers a completing
// attempt's REAL launch time. For a fixed-latency assertion every
// attempt takes the same number of clock ticks, so the runtime keeps a
// short ring of recent cbAssertionStart times and reports the
// completing attempt's true start on Success/Failure -- correct even
// for pipelined attempts, not the fire time.
module top;
  bit clk = 0, a = 0, b = 0;
  always #5 clk = ~clk;

  // same-tick assertion: start == completion, attemptStartTime == now
  assert property (@(posedge clk) a);

  // multi-tick: attempt starts when a holds, checks b one tick later;
  // attemptStartTime must be the START tick, not the completion tick
  assert property (@(posedge clk) a |=> b);

  initial begin
    #1 $m12aa_setup;
    // a true at posedge 5 only -> same-tick assertion fails @5;
    // |=> attempt starts @5, checks b @15 (b=0) -> fails @15 start=5
    a = 1; #8 a = 0;
    #40 $finish(0);
  end
endmodule
