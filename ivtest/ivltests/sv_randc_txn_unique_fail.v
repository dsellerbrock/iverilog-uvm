// Strict negative: randc variables cannot appear in uniqueness constraints.
class randc_txn_bad_unique_item;
  randc bit [1:0] cyclic_value;
  rand bit [1:0] ordinary_value;
  constraint bad_c { unique {cyclic_value, ordinary_value}; }
endclass

module test;
  randc_txn_bad_unique_item item;
endmodule
