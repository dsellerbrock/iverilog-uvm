module test;
  typedef struct { int value=37; } item_t;
  typedef item_t queue_t[$];
  // Outer fixed array remains an explicitly unsupported initialization shape.
  queue_t fixed_queues[2];
  typedef struct { queue_t fixed_queues[2]; } wrapper_t;
  wrapper_t wrapper;
endmodule
