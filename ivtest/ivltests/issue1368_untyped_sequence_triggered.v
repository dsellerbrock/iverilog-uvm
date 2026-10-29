module issue1368_untyped_sequence_triggered;
  bit clk, a;
  int passes, failures;
  always #5 clk = ~clk;

  sequence inner;
    a;
  endsequence

  sequence wrapper(x);
    x.triggered;
  endsequence

  assert property (@(posedge clk) wrapper(inner)) passes++;
  else failures++;

  initial begin
    a = 1;
    repeat (2) @(negedge clk);
    if (passes != 2 || failures)
      $fatal(1, "untyped triggered=%0d/%0d", passes, failures);
    $display("PASS triggered on untyped sequence formal");
    $finish(0);
  end
endmodule
