// Strict negative: randc variables cannot participate in dist constraints.
class randc_txn_bad_dist_item;
  randc bit [1:0] value;
  constraint bad_c { value dist {2'd0 := 1, 2'd3 := 1}; }
endclass

module test;
  randc_txn_bad_dist_item item;
endmodule
