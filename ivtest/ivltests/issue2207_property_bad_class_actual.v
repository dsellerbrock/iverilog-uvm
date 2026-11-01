module property_bad_class_actual;
  logic clk = 0, a = 1;
  class C; endclass
  C obj;
  always #5 clk = ~clk;
  property takes_integral(int n); a == n; endproperty
  ap: assert property (@(posedge clk) takes_integral(obj));
endmodule
