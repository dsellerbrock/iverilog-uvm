// A final block may run without another assertion clock after Kill.  Its
// generation guard must suppress only killed obligations, even though the
// clocked checker has not had an opportunity to acknowledge the generation.
module sv_assertkill_final_obligations;
  bit clk;
  bit req, ack;
  int sequence_failures, temporal_failures;

  active_strong_sequence: assert property (@(posedge clk)
      req |-> strong(##[1:$] ack))
    else sequence_failures++;

  active_strong_temporal: assert property (@(posedge clk)
      req |-> s_eventually(ack))
    else temporal_failures++;

  task automatic tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    req = 1;
    tick();
    req = 0;
    $assertkill(0, sv_assertkill_final_obligations.active_strong_sequence);
    $assertkill(0, sv_assertkill_final_obligations.active_strong_temporal);
    $asserton(0, sv_assertkill_final_obligations.active_strong_sequence);
    $asserton(0, sv_assertkill_final_obligations.active_strong_temporal);
    $finish;
  end

  final begin
    if (sequence_failures != 0 || temporal_failures != 0)
      $fatal(1, "killed final obligations fired: sequence=%0d temporal=%0d",
             sequence_failures, temporal_failures);
    $display("PASSED");
  end
endmodule
