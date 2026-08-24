// A fixed outer array is not itself a queue. Container methods require every
// fixed-prefix index before reaching the queue element.
class fixed_array_container_bad_holder;
  int values[2][$];
  int multi[2][3][$];
endclass

module sv_class_fixed_array_container_property_fail;
  initial begin
    automatic fixed_array_container_bad_holder holder = new;
    holder.values.push_back(1);
    holder.multi[0].push_back(2);
  end
endmodule
