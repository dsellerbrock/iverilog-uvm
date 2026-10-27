module test;
  bit clk = 0;
  bit start_s = 0, start_weak = 0, start_strong = 0;
  bit a = 0, b = 0, c = 0;
  int s_failures, weak_range_failures, strong_range_failures;
  always #5 clk = ~clk;

  property p_s_eventually;
    @(posedge clk) start_s |-> s_eventually a;
  endproperty
  property p_eventually_range;
    @(posedge clk) start_weak |-> eventually [1:2] b;
  endproperty
  property p_s_eventually_range;
    @(posedge clk) start_strong |-> s_eventually [1:2] c;
  endproperty
  assert property (p_s_eventually) else s_failures++;
  assert property (p_eventually_range) else weak_range_failures++;
  assert property (p_s_eventually_range) else strong_range_failures++;

  initial begin
    @(negedge clk); start_s = 1;
    @(negedge clk); start_s = 0; a = 1;
    @(negedge clk); start_weak = 1; start_strong = 1;
    @(negedge clk); start_weak = 0; b = 1;
    @(negedge clk); b = 0; c = 1;
    repeat (3) @(negedge clk);
    if (s_failures != 0 || weak_range_failures != 0 || strong_range_failures != 0)
      $fatal(1, "§16.12.13 eventually failures=%0d/%0d/%0d",
             s_failures, weak_range_failures, strong_range_failures);
    $display("PASSED: §16.12.13 strong and bounded weak/strong eventually");
    $finish(0);
  end
endmodule
