module test;
  int passes = 0;
  int failures = 0;

  initial begin
    assert (1'b1) passes++; else failures++;
    assert (1'b0) passes++; else failures++;
    assert (1'bx) passes++; else failures++;
    assert (1'bz) passes++; else failures++;

    if (passes != 1 || failures != 3)
      $fatal(1, "assert actions: passes=%0d failures=%0d", passes, failures);
    $display("PASSED");
  end
endmodule
