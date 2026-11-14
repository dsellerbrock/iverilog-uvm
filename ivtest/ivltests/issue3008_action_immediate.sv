module issue3008_action_immediate;
  bit clk = 0, a = 1;
  integer passes = 0, covers = 0;
  assert property (@(posedge clk) a) begin
    assert (a) passes = passes + 1; else $fatal(1, "immediate assert failed");
  end else $fatal(1, "concurrent assert failed");
  cover property (@(posedge clk) a) begin
    assert (a) covers = covers + 1; else $fatal(1, "immediate cover action failed");
  end
  initial begin
    #1 clk = 1;
    #1 if (passes != 1 || covers != 1) $fatal(1, "actions not executed");
    $display("PASS");
    $finish;
  end
endmodule
