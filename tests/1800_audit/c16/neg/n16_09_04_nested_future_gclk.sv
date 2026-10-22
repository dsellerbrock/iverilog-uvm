module test;
  logic clk = 0;
  logic a = 0, b = 0;
  global clocking gclk @(posedge clk); endclocking

  // IEEE 1800-2017/2023 §16.9.4: future global-clock functions may not nest.
  assert property (@($global_clock) $future_gclk(a || $rising_gclk(b)));
endmodule
