// Fixed arrays of queues are legal class-property types, but the current VVP
// representation can allocate independent inner containers only for instance
// properties. Static properties use signal-backed storage and must fail loudly.
class static_fixed_array_container_holder;
  static int values[2][$];
endclass

module sv_class_static_fixed_array_container_property_fail;
  initial
    static_fixed_array_container_holder::values[0].push_back(1);
endmodule
