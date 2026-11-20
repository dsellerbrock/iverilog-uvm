module issue3827_clockless_disable;
  bit clk, data;
  default clocking cb @(negedge clk); endclocking

  sequence endpoint;
    data;
  endsequence

  // The sequence needs its own clock in the disable condition.
  // See IEEE 1800-2017/2023 16.13.3 and 16.13.6.
  assert property (@(posedge clk) disable iff (endpoint.triggered) data);
  // Check the same requirement before constant folding.
  assert property (@(posedge clk)
    disable iff ((1'b0 && endpoint.triggered) || data) data);
endmodule
