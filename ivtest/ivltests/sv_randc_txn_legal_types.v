// Compile-positive polarity shared with Slang 11: randc is legal for integral
// leaves and arrays thereof; rand (not randc) is legal for class handles and
// unpacked structures.  Mode-call polarity is isolated in the focused mode
// fixtures so a mode implementation cap cannot obscure these type rules.
typedef enum bit [2:0] {
  RANDC_TXN_ENUM_A = 3'd1,
  RANDC_TXN_ENUM_B = 3'd3,
  RANDC_TXN_ENUM_C = 3'd6
} randc_txn_enum_t;

typedef struct packed {
  bit [2:0] opcode;
  bit [4:0] payload;
} randc_txn_packed_t;

typedef struct {
  rand int first;
  rand bit [7:0] second;
} randc_txn_unpacked_t;

class randc_txn_legal_child;
  rand int value;
endclass

class randc_txn_legal_item;
  randc randc_txn_enum_t enum_value;
  randc randc_txn_packed_t packed_value;
  randc bit [3:0] fixed_values[2];
  randc byte dynamic_values[];
  randc shortint queue_values[$];
  randc int assoc_values[string];
  rand randc_txn_legal_child child;
  rand randc_txn_unpacked_t unpacked_value;
endclass

module test;
  initial begin
    randc_txn_legal_item item;
    item = new;
  end
endmodule
