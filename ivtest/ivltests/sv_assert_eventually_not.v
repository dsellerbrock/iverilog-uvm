// IEEE 1800-2017 16.12.6 and 16.12.9: a one-cycle negated property is
// legal inside bounded eventually.  Property negation treats X/Z as a
// nonmatch of the operand (and therefore a match of `not'), unlike ordinary
// four-state logical negation.
module sv_assert_eventually_not;
  logic clk = 0;
  logic enabled = 0;
  logic trigger = 0;
  logic q = 1;
  int failures = 0;
  int wrong_time = 0;

  always #5 clk = ~clk;

  ap: assert property (@(posedge clk) disable iff (!enabled)
        trigger |-> eventually [0:5] not(q))
      else begin
        failures++;
        wrong_time += ($time != 155);
      end

  initial begin
    // Endpoint 0.
    @(negedge clk) enabled = 1;
    @(negedge clk) begin trigger = 1; q = 0; end
    @(negedge clk) begin trigger = 0; q = 1; end

    // Endpoint 5.
    @(negedge clk) trigger = 1;
    @(negedge clk) trigger = 0;
    repeat (4) @(negedge clk);
    q = 0;

    // First success at offset 6 is too late: exactly one failure at t=155.
    @(negedge clk) begin trigger = 1; q = 1; end
    @(negedge clk) trigger = 0;
    repeat (5) @(negedge clk);
    q = 0;

    // X and Z do not match q, so not(q) succeeds at endpoint 0.
    @(negedge clk) begin trigger = 1; q = 1'bx; end
    @(negedge clk) begin trigger = 0; q = 1; end
    @(negedge clk) begin trigger = 1; q = 1'bz; end
    @(negedge clk) begin trigger = 0; q = 1; end

    // Disabling an open window abandons it without a verdict.
    @(negedge clk) trigger = 1;
    @(negedge clk) begin trigger = 0; enabled = 0; end
    repeat (6) @(negedge clk);
    enabled = 1;

    repeat (2) @(negedge clk);
    if (failures != 1 || wrong_time != 0)
      $fatal(1, "failures=%0d wrong_time=%0d", failures, wrong_time);
    $display("PASSED");
    $finish;
  end
endmodule
