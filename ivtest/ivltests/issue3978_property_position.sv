module issue3978_property_position;
  bit clk, a, b;

  property antecedent(property x);
    x |-> b;
  endproperty

  property repeated(property x);
    x[*1];
  endproperty

  property delayed(x);
    ##0 x;
  endproperty

  property sequence_use(sequence x);
    x;
  endproperty

  assert property (@(posedge clk) antecedent(a));
  assert property (@(posedge clk) repeated(a));
  assert property (@(posedge clk) delayed(a |-> b));
  assert property (@(posedge clk) sequence_use(weak(a)));
endmodule
