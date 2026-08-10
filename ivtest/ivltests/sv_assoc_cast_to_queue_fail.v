// A legal explicit associative-array-to-queue conversion must fail loudly
// until the compiler implements the required element-wise conversion.
module sv_assoc_cast_to_queue_fail;
  typedef int assoc_t[string];
  typedef int queue_t[$];
  assoc_t source;

  initial $display("%p", queue_t'(source));
endmodule
