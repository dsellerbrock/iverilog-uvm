// Pins the residual gap left by sv_class_static_fixed_array_container_property.
//
// The container itself is supported: push_back, size(), delete() and foreach
// on a static fixed-array-of-queue property all work. Reading one ELEMENT
// through the indexed static property is not yet lowered, and must keep
// saying so rather than returning a wrong value.
class static_fixed_array_container_element_holder;
  static int values[2][$];
endclass

module sv_class_static_fixed_array_container_element_read_fail;
  int observed;

  initial begin
    static_fixed_array_container_element_holder::values[0].push_back(1);
    static_fixed_array_container_element_holder::values[0].push_back(2);
    observed = static_fixed_array_container_element_holder::values[0][1];
    $display("observed %0d", observed);
  end
endmodule
