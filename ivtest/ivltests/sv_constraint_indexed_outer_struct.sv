// IEEE 1800-2017/2023 18.4/18.5: constraints select randomized scalar
// members through an indexed fixed array of unpacked structures.
typedef enum bit [1:0] { indexed_kind_a = 2'd1, indexed_kind_b = 2'd3 }
  indexed_kind_t;

typedef struct {
  rand int value;
  int state;
  rand indexed_kind_t kind;
  indexed_kind_t state_kind;
} indexed_leaf_t;

typedef struct {
  rand indexed_leaf_t data;
} indexed_record_t;

class indexed_item_t;
  rand indexed_record_t leaves[2:1];
  rand indexed_record_t grid[3:2][1:0];
  bit impossible;

  constraint indexed_leaf_values {
    foreach (leaves[i]) leaves[i].data.value == leaves[i].data.state;
    foreach (leaves[i]) leaves[i].data.kind == leaves[i].data.state_kind;
    foreach (grid[i,j]) grid[i][j].data.value == grid[i][j].data.state;
    foreach (grid[i,j]) grid[i][j].data.kind == grid[i][j].data.state_kind;
    if (impossible) leaves[2].data.value != 17;
  }
endclass

module test;
  initial begin
    indexed_item_t item;
    int first_value;
    int second_value;

    item = new;
    item.leaves[2].data.state = 17;
    item.leaves[2].data.state_kind = indexed_kind_a;
    item.leaves[1].data.state = 29;
    item.leaves[1].data.state_kind = indexed_kind_b;
    item.grid[3][1].data.state = 31;
    item.grid[3][1].data.state_kind = indexed_kind_b;
    item.grid[3][0].data.state = 30;
    item.grid[3][0].data.state_kind = indexed_kind_a;
    item.grid[2][1].data.state = 21;
    item.grid[2][1].data.state_kind = indexed_kind_a;
    item.grid[2][0].data.state = 20;
    item.grid[2][0].data.state_kind = indexed_kind_b;
    if (!item.randomize()) $fatal(1, "indexed-struct solve failed");
    if (item.leaves[2].data.value != 17 || item.leaves[1].data.value != 29)
      $fatal(1, "foreach indexed-struct member constraints were lost");
    if (item.leaves[2].data.kind != indexed_kind_a
        || item.leaves[1].data.kind != indexed_kind_b)
      $fatal(1, "indexed-struct enum member constraints were lost");
    if (item.grid[3][1].data.value != 31 || item.grid[3][0].data.value != 30
        || item.grid[2][1].data.value != 21 || item.grid[2][0].data.value != 20)
      $fatal(1, "multidimensional indexed-struct constraints were lost");
    if (item.grid[3][1].data.kind != indexed_kind_b
        || item.grid[3][0].data.kind != indexed_kind_a
        || item.grid[2][1].data.kind != indexed_kind_a
        || item.grid[2][0].data.kind != indexed_kind_b)
      $fatal(1, "multidimensional indexed-struct enum constraints were lost");

    first_value = item.leaves[2].data.value;
    second_value = item.leaves[1].data.value;
    item.impossible = 1;
    if (item.randomize()) $fatal(1, "contradictory indexed-struct solve passed");
    if (item.leaves[2].data.value != first_value
        || item.leaves[1].data.value != second_value)
      $fatal(1, "failed indexed-struct solve did not roll back");

    $display("PASSED");
  end
endmodule
