module test;
  bit clk = 0;
  bit start_until = 0, start_until_with = 0, start_bad = 0;
  bit a = 0, b = 0, c = 0, d = 0, bad_a = 0, bad_b = 0;
  int until_failures, s_until_failures, with_failures, s_with_failures;
  int bad_until_failures, bad_s_until_failures;
  always #5 clk = ~clk;

  property p_until;
    @(posedge clk) start_until |-> (a until b);
  endproperty
  property p_s_until;
    @(posedge clk) start_until |-> (a s_until b);
  endproperty
  property p_until_with;
    @(posedge clk) start_until_with |-> (c until_with d);
  endproperty
  property p_s_until_with;
    @(posedge clk) start_until_with |-> (c s_until_with d);
  endproperty
  property p_bad_until;
    @(posedge clk) start_bad |-> (bad_a until bad_b);
  endproperty
  property p_bad_s_until;
    @(posedge clk) start_bad |-> (bad_a s_until bad_b);
  endproperty
  assert property (p_until) else until_failures++;
  assert property (p_s_until) else s_until_failures++;
  assert property (p_until_with) else with_failures++;
  assert property (p_s_until_with) else s_with_failures++;
  assert property (p_bad_until) else bad_until_failures++;
  assert property (p_bad_s_until) else bad_s_until_failures++;

  initial begin
    @(negedge clk);
    start_until = 1; start_until_with = 1; start_bad = 1;
    a = 1; c = 1; bad_a = 0;
    @(negedge clk);
    start_until = 0; start_until_with = 0; start_bad = 0;
    a = 0; b = 1; c = 1; d = 1;
    repeat (3) @(negedge clk);
    if (until_failures != 0 || s_until_failures != 0 ||
        with_failures != 0 || s_with_failures != 0 ||
        bad_until_failures != 1 || bad_s_until_failures != 1)
      $fatal(1, "§16.12.12 failures=%0d/%0d/%0d/%0d bad=%0d/%0d",
             until_failures, s_until_failures, with_failures, s_with_failures,
             bad_until_failures, bad_s_until_failures);
    $display("PASSED: §16.12.12 weak/strong until and until_with");
    $finish(0);
  end
endmodule
