module test;
  int passes = 0;
  int failures = 0;

  initial begin
    assume (1'b1) passes++; else failures++;
    assume (1'b0) passes++; else failures++;

    if (passes != 1 || failures != 1)
      $fatal(1, "assume actions: passes=%0d failures=%0d", passes, failures);
    $display("PASSED");
  end
endmodule
