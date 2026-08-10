// Strict negative: an unpacked struct is legal under rand, not randc; wrapping
// it in an unpacked array does not make the randc declaration legal.
typedef struct {
  int first;
  bit [7:0] second;
} randc_txn_bad_unpacked_t;

class randc_txn_bad_unpacked_item;
  randc randc_txn_bad_unpacked_t scalar_value;
  randc randc_txn_bad_unpacked_t dynamic_values[];
endclass

module test;
  randc_txn_bad_unpacked_item item;
endmodule
