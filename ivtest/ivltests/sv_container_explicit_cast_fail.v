// IEEE 1800-2017/2023 6.24.1 and 7.6 require equivalent element types for
// assignment-compatible queue/dynamic-array casts. These two directions must
// remain errors and must not inherit the ordinary-assignment bit/logic
// interoperability extension.
typedef real real_darray_t[];
typedef int int_queue_t[$];

module sv_container_explicit_cast_fail;
  int_queue_t int_q;
  real_darray_t real_d;

  initial begin
    real_d = real_darray_t'(int_q);
  end
endmodule
