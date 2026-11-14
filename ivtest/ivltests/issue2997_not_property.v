module issue2997_not_property;
  bit clk = 0;
  bit a = 0;
  integer ungrouped_failures = 0;
  integer grouped_failures = 0;
  integer sequence_failures = 0;
  integer grouped_sequence_failures = 0;

  always #5 clk = ~clk;
  assert property (@(posedge clk) not a) else ungrouped_failures++;
  assert property (@(posedge clk) not (a)) else grouped_failures++;
  assert property (@(posedge clk) not a ##1 1'b1) else sequence_failures++;
  assert property (@(posedge clk) not (a ##1 1'b1)) else grouped_sequence_failures++;

  initial begin
    @(negedge clk) a = 1;
    @(negedge clk) a = 0;
    @(negedge clk);
    if (ungrouped_failures != 1 || grouped_failures != 1 ||
        sequence_failures != 1 || grouped_sequence_failures != 1)
      $fatal(1, "incorrect negation results: %0d %0d %0d %0d",
             ungrouped_failures, grouped_failures,
             sequence_failures, grouped_sequence_failures);
    $display("PASS");
    $finish(0);
  end
endmodule
