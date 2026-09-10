module test;
  int runtime_value=3;
  typedef struct { int value=runtime_value; } bad_t;
  typedef struct { bad_t q[$]; } nested_t;
  bad_t direct[$];
  nested_t nested;
endmodule
