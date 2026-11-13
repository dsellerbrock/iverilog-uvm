// Step callbacks registered but never enabled deliver nothing (39.4.2: "By
// default, step callbacks are not enabled on any assertions"; 39.5.2: "By
// default, stepping is disabled for all assertions."). This endpoint fan-out
// form also refuses vpiAssertionEnableStep for now; see sva_step_attempt.
module m12_endpoint_fanout_step;
  logic clk = 0;
  logic start = 1, endpoint = 0, q = 0;
  integer failures = 0;

  always #5 clk = ~clk;

  ap: assert property (@(posedge clk)
        start ##[1:2] endpoint |=> q)
    else failures++;

  initial #1 $setup_endpoint_fanout_step;

  initial begin
    @(negedge clk) begin start = 0; endpoint = 1; end
    @(negedge clk) begin endpoint = 1; q = 0; end
    @(posedge clk);
    #1;
    if (failures == 1)
      $display("PASSED failures=%0d", failures);
    else
      $display("FAILED failures=%0d", failures);
    $finish;
  end
endmodule
