// IEEE 1800-2017/2023 18.4: nested random members of a rand unpacked
// structure participate in the containing class randomization.
typedef enum bit [2:0] {
  nested_kind_a = 3'd1,
  nested_kind_b = 3'd4,
  nested_kind_c = 3'd6
} nested_kind_t;

typedef struct {
  rand bit [7:0] value;
  rand nested_kind_t kind;
  randc bit [1:0] cycle;
  bit [7:0] state;
} nested_leaf_t;

typedef struct {
  rand nested_leaf_t leaf;
} nested_record_t;

typedef struct {
  rand nested_record_t nested;
} outer_record_t;

class nested_item_t;
  rand outer_record_t root;
  constraint nested_leaf_values {
    root.nested.leaf.value == root.nested.leaf.state;
    root.nested.leaf.state != 8'hff;
    root.nested.leaf.kind inside {nested_kind_a, nested_kind_c};
    root.nested.leaf.cycle inside {2'd1, 2'd3};
  }
endclass

module test;
  initial begin
    nested_item_t item;
    bit [1:0] first_cycle;
    bit [7:0] first_value;
    nested_kind_t first_kind;

    item = new;
    item.root.nested.leaf.state = 8'h5a;
    item.srandom(32'h1804_0510);
    if (!item.randomize()) $fatal(1, "first nested solve failed");
    if (item.root.nested.leaf.value !== 8'h5a
        || !(item.root.nested.leaf.kind inside {nested_kind_a, nested_kind_c}))
      $fatal(1, "nested member constraint or enum domain was lost");

    first_cycle = item.root.nested.leaf.cycle;
    first_value = item.root.nested.leaf.value;
    first_kind = item.root.nested.leaf.kind;
    item.root.nested.leaf.state = 8'hff;
    if (item.randomize()) $fatal(1, "contradictory nested solve passed");
    if (item.root.nested.leaf.value !== first_value
        || item.root.nested.leaf.kind !== first_kind
        || item.root.nested.leaf.cycle !== first_cycle)
      $fatal(1, "failed nested solve did not roll back values/history");

    item.root.nested.leaf.state = 8'ha6;
    if (!item.randomize()) $fatal(1, "nested solve after rollback failed");
    if (item.root.nested.leaf.value !== 8'ha6
        || item.root.nested.leaf.cycle === first_cycle
        || !(item.root.nested.leaf.kind inside {nested_kind_a, nested_kind_c}))
      $fatal(1, "nested randc or member solve did not resume");
    $display("PASSED");
  end
endmodule
