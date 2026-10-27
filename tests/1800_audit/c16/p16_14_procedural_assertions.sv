module test;
  bit clk = 0;
  bit pass_signal = 1;
  int assert_failures, assume_failures;

  always #5 clk = ~clk;

  initial begin
    assert property (@(posedge clk) pass_signal) else assert_failures++;
    assume property (@(posedge clk) pass_signal) else assume_failures++;
    cover property (@(posedge clk) pass_signal);
    @(posedge clk); #1;
    if (assert_failures != 0 || assume_failures != 0) begin
      $display("FAIL: procedural assertion failures=%0d assumption failures=%0d",
               assert_failures, assume_failures);
      $fatal(1);
    end
    $display("PASSED: §16.14 procedural assert/assume/cover statements");
    $finish;
  end
endmodule
