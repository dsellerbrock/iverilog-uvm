module test;
  bit clk = 0;
  bit done, ok = 1;
  int failures;

  always #5 clk = ~clk;

  property recurse_until_done(stop, valid);
    !stop |-> (valid |=> recurse_until_done(stop, valid));
  endproperty

  assert property (@(posedge clk) recurse_until_done(done, ok))
    else failures++;

  // IEEE 1800-2023 16.12.17: the attempt at 5 sees ok = 1, so it requires
  // recurse_until_done at 15. ok drops at the negedge at 10, so at 15
  // `valid |=> ...' is vacuously true both for that level and for the
  // attempt starting at 15: no attempt fails.
  initial begin
    @(negedge clk); ok = 0;
    @(posedge clk); #1;
    if (failures != 0) begin
      $display("FAIL: recursive property failures=%0d (expected 0)", failures);
      $fatal(1);
    end
    $display("PASSED: 16.12.17 recursive property continues to next cycle");
    $finish;
  end
endmodule
