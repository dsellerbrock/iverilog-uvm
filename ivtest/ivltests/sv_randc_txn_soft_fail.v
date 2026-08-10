// Strict negative: randc variables cannot participate in soft constraints.
class randc_txn_bad_soft_item;
  randc bit [1:0] value;
  constraint bad_c { soft value == 2'd1; }
endclass

module test;
  randc_txn_bad_soft_item item;
endmodule
