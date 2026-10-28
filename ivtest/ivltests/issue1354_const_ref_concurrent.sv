module top;
  bit clk;
  int value = 1;
  int passes, failures;

  always #5 clk = ~clk;
  always @(posedge clk) value = 0;

  function automatic bit const_ref_ok(const ref int arg);
    return arg != 0;
  endfunction

  assert property (@(posedge clk) const_ref_ok(value)) passes++;
  else failures++;

  initial begin
    #6;
    if (passes != 1 || failures != 0)
      $fatal(1, "pass/fail=%0d/%0d", passes, failures);
    $display("PASS const-ref concurrent");
    $display("PASSED");
    $finish(0);
  end
endmodule
