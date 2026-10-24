// IEEE 1800-2017/2023 16.7: finite cycle-delay range upper bound must be
// greater than or equal to its lower bound.
module sv_assert_cycle_delay_reversed_fail;
  reg clk = 0, a = 0, b = 0;
  assert property (@(posedge clk) a |-> ##[3:1] b);
endmodule
