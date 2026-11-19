// IEEE 1800-2017/2023 16.9 and 16.13.1.
module issue2994_sequence_operands;
  bit clk1, clk2, a, b, c, d;
  property p; a |-> b; endproperty

  cover sequence ((@(posedge clk1) a ##1 b) within (@(posedge clk2) c ##2 d));
  assert property (@(posedge clk1) (a |-> b) within c);
  assert property (@(posedge clk1) a throughout p);
endmodule
