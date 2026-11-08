// Issue #2755: each $nochange violation toggles the notifier exactly once
// (IEEE 1800-2017/2023 31.4.6 offsets, 31.6 notifier). One data change
// inside the region must not also be reported again at the trailing
// reference edge.
`timescale 1ns/100ps
module issue2755_nochange_dut(input clk, input d, input e, input f);
  reg n_zero = 0, n_wide = 0, n_shrink = 0;
  specify
    $nochange(posedge clk, d, 0, 0, n_zero);
    $nochange(posedge clk, e, 1, 1, n_wide);
    $nochange(posedge clk, f, 0, -2, n_shrink);
  endspecify
endmodule

module issue2755_nochange_notifier;
  reg clk = 0, d = 0, e = 0, f = 0;
  integer zero_count = 0, wide_count = 0, shrink_count = 0;
  issue2755_nochange_dut u(clk, d, e, f);

  always @(u.n_zero) zero_count = zero_count + 1;
  always @(u.n_wide) wide_count = wide_count + 1;
  always @(u.n_shrink) shrink_count = shrink_count + 1;

  initial begin
    #10 clk = 1;      // region (10, 20) for d, (9, 21) for e, (10, 18) for f
    #2  d = 1;        // 12: inside the zero-offset region
    #1  f = 1;        // 13: inside the shrunk region
    #6  f = 0;        // 19: after the shrunk region ends at 18
    #1  clk = 0;      // 20
    #0.5 e = 1;       // 20.5: inside the widened region only
    #10;
    if (zero_count === 1 && wide_count === 1 && shrink_count === 1)
      $display("PASSED");
    else
      $display("FAILED: notifier toggles zero=%0d wide=%0d shrink=%0d (want 1 1 1)",
               zero_count, wide_count, shrink_count);
  end
endmodule
