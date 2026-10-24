module test;
  bit clk = 0;
  bit a, b;
  int implies_failures, iff_failures;

  always #5 clk = ~clk;

  property p_implies;
    a implies b;
  endproperty

  property p_iff;
    a iff b;
  endproperty

  assert property (@(posedge clk) p_implies) else implies_failures++;
  assert property (@(posedge clk) p_iff) else iff_failures++;

  initial begin
    for (int k = 0; k < 4; k++) begin
      @(negedge clk);
      a = k[1]; b = k[0];
      @(posedge clk);
      #1;
    end
    if (implies_failures != 1 || iff_failures != 2) begin
      $display("FAIL: implies=%0d (expected 1), iff=%0d (expected 2)",
               implies_failures, iff_failures);
      $fatal(1);
    end
    $display("PASSED: §16.12.8 implies/iff truth tables");
    $finish;
  end
endmodule
