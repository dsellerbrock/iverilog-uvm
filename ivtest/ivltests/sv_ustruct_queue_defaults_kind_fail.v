module test;
  typedef struct packed { int value=3; } bad_t;
  bad_t queue_of_bad[$];
endmodule
