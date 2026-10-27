module test;
  bit clk = 0;
  bit seq_ov, prop_ov, seq_nov, prop_nov;
  int failures;
  always #5 clk = ~clk;

  initial begin
    @(negedge clk);
    seq_ov = 1; prop_ov = 1;
    assert property (@(posedge clk) seq_ov #-# prop_ov) else failures++;
    @(negedge clk);
    seq_ov = 0; seq_nov = 1; prop_nov = 0;
    assert property (@(posedge clk) seq_nov #=# prop_nov) else failures++;
    @(negedge clk);
    seq_nov = 0; prop_nov = 1;
    repeat (2) @(negedge clk);
    if (failures != 0) $fatal(1, "§16.12.9 followed-by failures=%0d", failures);
    $display("PASSED: §16.12.9 overlapped and nonoverlapped followed-by");
    $finish(0);
  end
endmodule
