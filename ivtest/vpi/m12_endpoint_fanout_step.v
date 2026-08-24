// A nonoverlapped endpoint is itself a successful sequence step even though
// its consequence record is allocated after consequence advancement. At t=25
// that endpoint step coexists with failure of the older consequence; both
// callback reasons must survive the once-per-checker/tick aggregates.
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
