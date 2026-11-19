module issue2874;
  bit clk = 0;
  always #5 clk = ~clk;

  int x = -99;
  int named_passes, named_failures, queued_passes;
  int unnamed_passes, unnamed_failures;

  always @(posedge clk) begin : named_block
    static int x = 1;
    x = -x;
    // This sees the preceding value of the local x, even though the
    // procedure just changed it and the module declares another x.
    assert property (x > 0) begin
      if ($time != 5 || x != -1) $fatal(1, "wrong named-block pass");
      named_passes++;
    end else begin
      if ($time != 15 || x != 1) $fatal(1, "wrong named-block failure");
      named_failures++;
    end
    // The two reads use different regions and refer to the same storage.
    assert property (x != const'(x)) queued_passes++;
    else $fatal(1, "static sample equals queue-time value");
  end

  always @(posedge clk) begin
    begin
      static bit [1:0] bits = 2'b01;
      bit idx;
      idx = !idx;
      // The index and the selected variable both come from Preponed.
      assert property (@(posedge clk) bits[idx]) begin
        if ($time != 5) $fatal(1, "wrong unnamed-block pass");
        unnamed_passes++;
      end else begin
        if ($time != 15) $fatal(1, "wrong unnamed-block failure");
        unnamed_failures++;
      end
    end
  end

  initial begin
    #22;
    if (named_passes != 1 || named_failures != 1 || queued_passes != 2 ||
        unnamed_passes != 1 || unnamed_failures != 1 || x != -99)
      $fatal(1, "incorrect results");
    $display("PASSED");
    $finish(0);
  end
endmodule
