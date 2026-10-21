module test;
  bit a = 0;
  wire not_a = ~a;
  int glitch_failures = 0;
  int stable_failures = 0;

  task record_glitch_failure;
    glitch_failures++;
  endtask

  task record_stable_failure;
    stable_failures++;
  endtask

  always_comb assert #0 (not_a != a) else record_glitch_failure();

  initial begin
    #1 a = 1'b1;
    #1;
    if (glitch_failures != 0)
      $fatal(1, "transient failure was not flushed: %0d", glitch_failures);

    assert #0 (1'b0) else record_stable_failure();
    #1;
    if (stable_failures != 1)
      $fatal(1, "stable failure action count=%0d", stable_failures);
    $display("PASSED");
  end
endmodule
