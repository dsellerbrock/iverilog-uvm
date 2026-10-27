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

  initial begin
    @(negedge clk); ok = 0;
    @(posedge clk); #1;
    if (failures != 2) begin
      $display("FAIL: recursive property failures=%0d (expected 2)", failures);
      $fatal(1);
    end
    $display("PASSED: §16.12.17 recursive property continues to next cycle");
    $finish;
  end
endmodule
