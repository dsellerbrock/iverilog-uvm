// IEEE 1800-2017 16.5.1: a concurrent assertion samples its operands in the
// Preponed region. A net with explicit drive strength uses the strength-aware
// vvp_wire_vec8 filter, but must retain the same one-slot history as an
// ordinary four-state signal.
module sv_assert_preponed_resolved_net_strength;
  logic clk = 1'b0;
  logic driver = 1'b0;
  wire resolved_net;

  // The non-default strength makes this a strength-aware resolved net rather
  // than an ordinary vvp_wire_vec4 signal.
  assign (pull1, strong0) resolved_net = driver;

  int failures = 0;

  sampled_zero: assert property
      (@(posedge clk) resolved_net === 1'b0)
    else failures++;

  // This Active-region process is released by the same edge as the assertion
  // sampler. The clock event itself occurs while resolved_net is zero; this
  // assignment changes it only after that event, later in the time slot.
  always @(posedge clk) begin
    if (resolved_net !== 1'b0)
      $fatal(1, "resolved net was not zero at the clock edge");
    driver = 1'b1;
  end

  initial begin
    #5;
    // The assertion clock occurs while resolved_net is still zero. The
    // edge-triggered process above updates it later in this same time slot.
    clk = 1'b1;

    #1;
    if (resolved_net !== 1'b1)
      $fatal(1, "resolved net did not settle to one");
    if (failures != 0)
      $fatal(1, "assertion read the late live value: failures=%0d", failures);

    $display("PASSED");
  end
endmodule
