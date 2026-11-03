module issue1366_action_past;
  bit clk, data;
  int checks, errors;

  always #5 clk = ~clk;

  assert property (@(posedge clk) data)
    else begin
      if ($time == 25) begin
        checks++;
        $display("action t=%0t current=%b past=%b", $time, data, $past(data));
        if ($past(data) !== 1'b1) errors++;
      end
    end

  initial begin
    data = 0;
    @(negedge clk) data = 1;
    @(negedge clk) data = 0;
    @(negedge clk);
    if (checks != 1 || errors)
      $fatal(1, "action clock checks=%0d errors=%0d", checks, errors);
    $display("PASS sampled value function inherits action-block leading clock");
    $display("PASSED");
    $finish(0);
  end
endmodule
