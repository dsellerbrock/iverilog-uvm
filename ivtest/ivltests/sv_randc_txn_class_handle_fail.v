// Strict negative: rand may recursively randomize class handles; randc may not.
class randc_txn_bad_handle_child;
  rand int value;
endclass

class randc_txn_bad_handle_item;
  randc randc_txn_bad_handle_child scalar_handle;
  randc randc_txn_bad_handle_child handle_array[2];
endclass

module test;
  randc_txn_bad_handle_item item;
endmodule
