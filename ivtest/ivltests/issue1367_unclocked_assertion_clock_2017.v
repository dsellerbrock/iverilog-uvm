module top;
  bit clk, data;
  assert property (@(posedge $past(clk)) data);
endmodule
