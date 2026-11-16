// IEEE 1800-2023 16.12.10: the nexttime/s_nexttime index "shall be a
// non-negative integer constant expression".
module issue3006_nexttime_negative_ce;
  bit clk, a;
  assert property (@(posedge clk) nexttime[-1] (a));
  assert property (@(posedge clk) s_nexttime[-1] (a));
endmodule
