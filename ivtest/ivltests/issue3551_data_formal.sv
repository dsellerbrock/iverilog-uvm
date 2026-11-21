module issue3551_data_formal;
  bit clk, a, b;

  sequence s(bit data);
    b;
  endsequence

  assert property (@(posedge clk) s(.data(a ##1 b)));
endmodule
