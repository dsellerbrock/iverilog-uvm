module test;
  typedef struct { int value=37; } item_t;
  typedef item_t pair_t[2];
  // The outer queue has no defaults to apply; its array element remains unsupported.
  pair_t rows[$];
  typedef struct { pair_t rows[$]; } nested_t;
  nested_t nested;
endmodule
