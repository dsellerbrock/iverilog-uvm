module issue2988_sequence_formal_valid;
  bit clk = 0;
  int passes = 0, failures = 0;
  always #5 clk = ~clk;
  sequence local_arg(local input int x);
    (1'b1, x = 2);
  endsequence
  sequence untyped_arg(x);
    (1'b1, x = 3) ##1 (x == 3);
  endsequence
  property p;
    int value = 0;
    @(posedge clk) untyped_arg(value);
  endproperty
  assert property (@(posedge clk) local_arg(0)) passes++; else failures++;
  assert property (p) passes++; else failures++;
  initial begin
    #16;
    if (passes != 3 || failures != 0) $fatal(1, "passes=%0d failures=%0d", passes, failures);
    $display("PASSED");
    $finish(0);
  end
endmodule
