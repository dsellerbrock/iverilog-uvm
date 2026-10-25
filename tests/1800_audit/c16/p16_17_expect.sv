module test;
  bit clk = 0;
  bit pass_signal = 1, fail_signal;
  int passes, failures;

  always #5 clk = ~clk;

  initial begin
    expect (@(posedge clk) pass_signal) passes++;
    else failures++;
    expect (@(posedge clk) fail_signal) passes++;
    else failures++;

    #1;
    if (passes != 1 || failures != 1) begin
      $display("FAIL: expect passes=%0d failures=%0d (expected 1 each)",
               passes, failures);
      $fatal(1);
    end
    $display("PASSED: §16.17 expect blocks and resumes on pass/fail");
    $finish;
  end
endmodule
