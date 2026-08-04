module top;
  logic assertion_condition = 1'b1;
  logic ordinary_enable = 1'b0;
  logic action_seen;

  always_comb begin
    action_seen = 1'b0;
    assert (assertion_condition) begin
      action_seen = 1'b1;
      $display("assertion action ran");
    end else begin
      $error("unexpected assertion failure");
    end

    // This is ordinary procedural behavior, so its existing synthesis
    // diagnostic must remain. Only assertion action blocks are exempt.
    if (ordinary_enable)
      $display("ordinary procedural system task");
  end

  initial begin
    #1;
    if (action_seen !== 1'b1)
      $display("FAILED: immediate assertion action did not execute");
    else
      $display("PASSED");
  end
endmodule
