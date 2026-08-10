// An associative map object is not an ordinary queue, despite the shared
// internal QUEUE carrier.
module sv_assoc_to_queue_fail;
  typedef int assoc_t[string];
  assoc_t source;
  int target[$];

  initial target = source;
endmodule
