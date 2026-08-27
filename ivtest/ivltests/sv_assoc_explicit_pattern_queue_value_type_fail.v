// IEEE 1800-2017/2023 7.9.11 and 10.9: every explicit value must be
// assignment-compatible with the associative array's element type.
module main;
  typedef int int_queue_t[$];
  int_queue_t values[string] = '{"not-a-queue":7};
endmodule
