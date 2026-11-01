module issue726_property_local_unassigned_actual_fail;
  logic clk = 0;
  always #5 clk = ~clk;

  property child(local input int value);
    value == 1;
  endproperty

  property parent;
    int x;
    child(x);
  endproperty

  ap: assert property (@(posedge clk) parent);
endmodule
