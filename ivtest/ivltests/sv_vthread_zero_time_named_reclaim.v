// A completed zero-time named-block activation must be reclaimed without
// waiting for the Active queue to become empty. Keeping every completed
// vthread on the delayed-deletion queue made this finite loop consume memory
// in proportion to its iteration count because the next activation was
// always ready in Active.
module sv_vthread_zero_time_named_reclaim #(
  parameter int ITERATIONS = 1_000_000
);
  int errors;

  initial begin
    for (int i = 0; i < ITERATIONS; i++) begin : activation
      automatic int snapshot = i;
      if (snapshot != i)
        errors++;
    end

    if (errors != 0)
      $display("FAILED -- %0d named-block activation errors", errors);
    else
      $display("PASSED");
  end
endmodule
