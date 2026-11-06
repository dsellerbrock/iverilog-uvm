// IEEE 1800-2017/2023 16.9.4: the global clocking sampled value functions
// "may be used only if global clocking is defined".
module issue712_past_gclk_no_global_fail;
  bit clk, a;
  c1: assert property (@(posedge clk) $rose_gclk(a));
endmodule
