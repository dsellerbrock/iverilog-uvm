// IEEE 1800-2017 7.5/10.8: a dynamic array target can only be assigned
// another dynamic array/queue (or `new[...]`, or an assignment pattern).
// Assigning a plain vector expression must be rejected loudly. The fork's
// queue-slice compile-progress leniency (runtime-bounds q[lo:hi] lowering
// as LOGIC) once let ANY vectorable expression through here, and the code
// generator silently stored null (ivtest br_gh265 — silent miscompile).
module darray_scalar_assign;
  typedef bit [3:0] array_t[];
  array_t array;
  initial begin
    array = 8'd1 << 4;   // error: cannot be implicitly cast to target type
  end
endmodule
