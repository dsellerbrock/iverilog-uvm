module kv_debug_overlay_check;
  bit clk = 0;
  bit trigger = 0;
  logic [31:0] actual = 32'hbad0_0000;
  localparam logic [31:0] expected = 32'hcafe_0000;
  always #5 clk = ~clk;

  function automatic logic check_value(input logic report_error);
    if (actual != expected) begin
      if (report_error)
        $display("SVA ERROR: KV[0][0] debug flush failed. Expected: %h, Got: %h, SelValue: 0", expected, actual);
      return 1'b0;
    end
    return 1'b1;
  endfunction

  KV_debug_comprehensive: assert property (@(posedge clk) trigger |=> check_value(1'b0))
    else begin
      $display("SVA ERROR: KV debug flush comprehensive check failed");
      void'(check_value(1'b1));
    end

  initial begin
    #1;
    if ($test$plusargs("trigger")) trigger = 1;
    if ($test$plusargs("match")) actual = expected;
    #10 trigger = 0;
    #40;
    if ($test$plusargs("trigger") && !$test$plusargs("match"))
      $display("EXPECTED_ASSERTION_FAILURE_OBSERVED");
    else
      $display("TESTCASE PASSED");
    $finish;
  end
endmodule
