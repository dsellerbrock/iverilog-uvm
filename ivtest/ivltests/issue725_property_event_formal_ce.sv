// IEEE 1800-2017/2023 16.12.18: an event expression is an actual only of an
// event (or untyped) formal; a typed non-event formal cannot take one.
module t;
  logic clk = 0, a = 1;
  property r(logic x); @(posedge clk) x; endproperty
  ar: assert property (r(posedge clk));
endmodule
