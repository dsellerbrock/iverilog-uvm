// The type is legal SystemVerilog, but this implementation currently supports
// fixed arrays of queues/maps only as direct non-static class properties. Keep
// the struct-nested boundary loud until its member walkers preserve both index
// levels.

typedef struct {
  int values[0:1][$];
} nested_fixed_queue_struct_t;

class nested_fixed_queue_holder;
  nested_fixed_queue_struct_t payload;
endclass

module sv_class_struct_nested_fixed_array_container_fail;
  initial begin
    automatic nested_fixed_queue_holder holder = new;
    holder.payload.values[0].push_back(1);
  end
endmodule
