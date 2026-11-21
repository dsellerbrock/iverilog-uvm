module issue3978_property_cycle;
  bit clk;

  property identity(x);
    x;
  endproperty

  property actual_cycle;
    identity(1'b1 |-> actual_cycle);
  endproperty

  property default_cycle(x = (1'b1 |-> default_cycle()));
    x;
  endproperty
endmodule
