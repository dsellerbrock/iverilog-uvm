module test;
  bit clk = 0, start = 0, start_range = 0, start_strong = 0;
  bit a = 1, b = 1, c = 1;
  int always_failures, range_failures, strong_failures;
  always #5 clk = ~clk;

  property p_always;
    @(posedge clk) start |-> always a;
  endproperty
  property p_range;
    @(posedge clk) start_range |-> always [0:1] b;
  endproperty
  property p_s_always;
    @(posedge clk) start_strong |-> s_always [0:1] c;
  endproperty
  assert property (p_always) else always_failures++;
  assert property (p_range) else range_failures++;
  assert property (p_s_always) else strong_failures++;

  initial begin
    @(negedge clk); start = 1; start_range = 1; start_strong = 1;
    @(negedge clk); start = 0; start_range = 0; start_strong = 0; b = 0;
    @(negedge clk); a = 0;
    repeat (3) @(negedge clk);
    if (always_failures != 1 || range_failures != 1 || strong_failures != 0)
      $fatal(1, "§16.12.11 always counts=%0d/%0d/%0d",
             always_failures, range_failures, strong_failures);
    $display("PASSED: §16.12.11 weak/ranged always and strong ranged always");
    $finish(0);
  end
endmodule
