// Both arms of a conditional source must satisfy an explicit positional-
// container cast. The false arm has a non-equivalent element type even when
// the run-time condition selects the assignment-compatible true arm.
typedef real conditional_fail_real_darray_t[];
typedef int conditional_fail_int_darray_t[];
typedef real conditional_fail_real_queue_t[$];

module sv_container_conditional_explicit_cast_fail;
  bit choose = 1'b1;
  real popped;
  conditional_fail_real_darray_t good_source;
  conditional_fail_int_darray_t bad_source;

  initial begin
    popped = conditional_fail_real_queue_t'(
          choose ? good_source : bad_source).pop_front();
  end
endmodule
