module sv_assert_clocking_input_sample;
  logic clk = 0;
  logic a = 1;
  int direct_failures = 0;
  int clocking_failures = 0;
  time direct_failure_time = 0;
  time clocking_failure_time = 0;

  always #5 clk = !clk;

  clocking cb @(posedge clk);
    input a;
  endclocking

  property direct_value;
    @(posedge clk) a;
  endproperty

  property clocking_value;
    @(posedge clk) cb.a;
  endproperty

  assert property (direct_value) else begin
    direct_failures++;
    direct_failure_time = $time;
  end
  assert property (clocking_value) else begin
    clocking_failures++;
    clocking_failure_time = $time;
  end

  initial begin
    #12 a = 0;
    #6 a = 1;
    @(posedge clk);
    #1;
    if (direct_failures != 1 || direct_failure_time != 15)
      $fatal(1, "direct assertion failures=%0d at %0t", direct_failures, direct_failure_time);
    if (clocking_failures != 1 || clocking_failure_time != 15)
      $fatal(1, "clocking assertion failures=%0d at %0t", clocking_failures, clocking_failure_time);
    $display("PASSED");
    $finish(0);
  end
endmodule
