module test;
  bit clk = 0;
  bit a, b, c, d;
  int and_failures, or_failures;

  always #5 clk = ~clk;

  property p_and;
    @(posedge clk)
    (a |-> b) and (c |-> d);
  endproperty

  property p_or;
    @(posedge clk)
    (a |-> b) or (c |-> d);
  endproperty

  assert property (p_and) else and_failures++;
  assert property (p_or) else or_failures++;

  initial begin
    for (int k = 0; k < 4; k++) begin
      @(negedge clk);
      a = 1; c = 1; b = k[1]; d = k[0];
      @(posedge clk);
      #1;
    end
    if (and_failures != 3 || or_failures != 1) begin
      $display("FAIL: and=%0d (expected 3), or=%0d (expected 1)", and_failures, or_failures);
      $fatal(1);
    end
    $display("PASSED: §§16.12.4-16.12.5 property or/and truth tables");
    $finish;
  end
endmodule
