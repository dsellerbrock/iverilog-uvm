module test;
  typedef struct { int value=37; } item_t;
  typedef item_t pair_t[2];
  // Queues of fixed-array struct values are empty until explicitly populated.
  pair_t rows[$];
  typedef struct { pair_t rows[$]; } nested_t;
  nested_t nested;
  initial begin
    if (rows.size() != 0 || nested.rows.size() != 0)
      $fatal(1, "fixed-array struct queues did not start empty");
    $display("PASSED");
  end
endmodule
