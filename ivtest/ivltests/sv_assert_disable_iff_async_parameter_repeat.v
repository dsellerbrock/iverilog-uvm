// IEEE 1800-2017 16.12: disable iff is asynchronous.  A true pulse aborts
// pending attempts even when it occurs entirely between assertion-clock
// events; deasserting it before the next clock must not resurrect them.
//
// The parameter-valued repetition selects the instance-elaborated checker
// used by OpenTitan's prim_esc_rxtx assertions.
module sv_assert_disable_iff_async_parameter_repeat #(
  parameter int N = 1
);
  logic clk = 0;
  logic start = 0;
  logic keep = 1;
  logic result = 1;
  logic disable_i = 0;
  integer failures = 0;

  always #5 clk = ~clk;

  checked: assert property (@(posedge clk)
    disable iff (disable_i)
    start ##1 keep[*N] |-> ##1 result)
  else
    failures += 1;

  initial begin
    // Launch at the first following posedge.
    @(negedge clk) start = 1;
    // The repeat's sole keep cycle is the next posedge.
    @(negedge clk) start = 0;
    // Pulse disable entirely between that endpoint and its ##1 verdict.
    // The false result would fail if the killed attempt were resurrected.
    @(negedge clk) begin
      result = 0;
      disable_i = 1;
    end
    #1 disable_i = 0;
    @(negedge clk);

    if (failures != 0) begin
      $display("FAILED -- off-clock disable pulse did not abort the pending parameter-repetition attempt (failures=%0d)",
               failures);
      $finish_and_return(1);
    end
    $display("PASSED");
    $finish;
  end
endmodule
