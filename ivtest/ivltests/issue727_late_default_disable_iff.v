module issue727_late_default_disable_iff;
  bit clk = 0;
  bit rst = 1;
  int failures = 0;

  always #5 clk = ~clk;

  assert property (@(posedge clk) 1'b0) else failures++;

  initial begin
    #6;
    if (failures != 0)
      $fatal(1, "late default did not disable assertion during reset");
    rst = 0;
    #10;
    if (failures != 1)
      $fatal(1, "assertion should fire once after reset, got %0d", failures);
    $display("PASS");
    $finish;
  end

  default disable iff rst;
endmodule
