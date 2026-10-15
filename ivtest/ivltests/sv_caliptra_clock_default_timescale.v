// IEEE 1800-2017/2023 §3.14.2.3 permits an implementation-specific default.
// Keep Caliptra's unit-bearing clock delay nonzero without a `timescale.
module sv_caliptra_clock_default_timescale;
  bit core_clk;
  integer transitions = 0;

  always begin
    core_clk = #5ns ~core_clk;
    transitions = transitions + 1;
  end

  initial begin
    #21ns;
    if ($timeunit != -12 || $timeprecision != -12)
      $fatal(1, "default timeunit/precision should be 1ps/1ps");
    if (transitions != 4 || core_clk !== 1'b0)
      $fatal(1, "Caliptra clock did not make four transitions");
    $display("PASSED");
    $finish;
  end
endmodule
