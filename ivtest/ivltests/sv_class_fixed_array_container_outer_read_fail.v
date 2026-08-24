// Reading the complete fixed outer property must not reuse the dynamic-array
// materializer: its words are queue/map objects, not packed vector elements.
class fixed_container_outer_read_holder;
  int values[2][$];
endclass

module sv_class_fixed_array_container_outer_read_fail;
  initial begin
    automatic fixed_container_outer_read_holder holder = new;
    $display("%p", holder.values);
  end
endmodule
