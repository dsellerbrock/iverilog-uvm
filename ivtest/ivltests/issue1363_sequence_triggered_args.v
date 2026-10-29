module issue1363_sequence_triggered_args;
  bit clk, a;
  int passes, failures;
  always #5 clk = ~clk;

  sequence one(x);
    x;
  endsequence

  assert property (@(posedge clk) one(a).triggered) passes++;
  else failures++;

  initial begin
    a = 1;
    repeat (2) @(negedge clk);
    if (passes != 2 || failures)
      $fatal(1, "argument triggered=%0d/%0d", passes, failures);
    $display("PASS triggered named sequence with actual argument");
    $finish(0);
  end
endmodule
