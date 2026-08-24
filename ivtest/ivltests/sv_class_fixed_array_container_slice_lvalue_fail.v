// Queue slice assignment is legal, but the fixed-property target needs a
// dedicated exact-cardinality writeback path. Reject it until that path exists.
class fixed_container_slice_lvalue_holder;
  int values[2][$];
  real residual_q[$];
endclass

module sv_class_fixed_array_container_slice_lvalue_fail;
  initial begin
    automatic fixed_container_slice_lvalue_holder holder = new;
    automatic int replacement[$] = '{7, 8};
    holder.values[0] = '{1, 2};
    holder.residual_q.push_back(1.0);
    holder.values[0][0:1] = replacement;
    // A scalar queue element has no further unpacked dimension. Never keep
    // the partially selected l-value and silently overwrite residual_q[0].
    holder.residual_q[0][1] = 5.0;
  end
endmodule
