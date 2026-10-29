module top;
  bit clk, rst, data;
  assert property (@(posedge clk) disable iff ($past(rst)) data);
endmodule
