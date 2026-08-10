// Strict negative: randc variables cannot appear in solve-before ordering.
class randc_txn_bad_order_item;
  randc bit [1:0] cyclic_value;
  rand bit [1:0] ordinary_value;
  constraint bad_c { solve cyclic_value before ordinary_value; }
endclass

module test;
  randc_txn_bad_order_item item;
endmodule
