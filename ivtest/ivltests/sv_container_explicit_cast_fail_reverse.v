// IEEE 1800-2017/2023 6.24.1 and 7.6 require equivalent element types for
// assignment-compatible queue/dynamic-array casts. This reverse direction is
// separate because Icarus stops elaborating a top after its first cast error.
typedef real reverse_real_darray_t[];
typedef int reverse_int_queue_t[$];

module sv_container_explicit_cast_fail_reverse;
  reverse_int_queue_t int_q;
  reverse_real_darray_t real_d;

  initial begin
    int_q = reverse_int_queue_t'(real_d);
  end
endmodule
