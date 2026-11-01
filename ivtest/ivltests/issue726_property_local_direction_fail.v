module issue726_property_local_direction_fail;
  property bad_inout(local inout int value);
    value == 0;
  endproperty

  property bad_output(local output int value);
    value == 0;
  endproperty
endmodule
