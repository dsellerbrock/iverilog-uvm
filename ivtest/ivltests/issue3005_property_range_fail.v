// IEEE 1800-2023 16.12.11: s_always takes a bounded range, and range bounds
// are non-negative with min <= max; 16.12.13: weak eventually also takes a
// bounded range.
module issue3005_property_range_fail;
  bit clk, a;
  a1: assert property (@(posedge clk) s_always [2:$] (a));
  a2: assert property (@(posedge clk) always [-1:2] (a));
  a3: assert property (@(posedge clk) always [3:2] (a));
  a4: assert property (@(posedge clk) s_always [3:2] (a));
  a5: assert property (@(posedge clk) eventually [2:$] (a));
  a6: assert property (@(posedge clk) always [$:2] (a));
endmodule
