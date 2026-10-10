// IEEE 1800-2017/2023 18.4: a rand class handle in a rand unpacked
// structure joins the containing object's randomization.
class struct_handle_leaf;
  bit [7:0] target;
  rand bit [7:0] value;
  randc bit [1:0] cycle;
  int pre_calls, post_calls;
  function bit [7:0] target_value(); return target; endfunction
  constraint leaf_value { value == target_value(); }
  function void pre_randomize(); pre_calls++; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass

typedef struct { rand struct_handle_leaf obj; } struct_handle_record_t;

class struct_handle_parent;
  rand struct_handle_record_t left, right;
  bit [7:0] expected;
  constraint shared_leaf {
    left.obj.value == expected;
    right.obj.value == expected;
  }
endclass

module test;
  initial begin
    struct_handle_parent item;
    struct_handle_leaf leaf;
    bit [1:0] first_cycle;

    item = new;
    leaf = new;
    leaf.target = 8'h5a;
    item.expected = 8'h5a;
    item.left.obj = leaf;
    item.right.obj = leaf;
    item.srandom(32'h419_1804);
    if (!item.randomize()) $fatal(1, "nested class-handle solve failed");
    if (item.left.obj != leaf || item.right.obj != leaf
        || leaf.value !== 8'h5a || leaf.pre_calls != 1 || leaf.post_calls != 1)
      $fatal(1, "aliased nested handle was not solved once in place");
    first_cycle = leaf.cycle;

    item.expected = 8'ha5;
    if (item.randomize()) $fatal(1, "contradictory nested handle solve passed");
    if (leaf.value !== 8'h5a || leaf.cycle !== first_cycle
        || leaf.pre_calls != 2 || leaf.post_calls != 1)
      $fatal(1, "failed nested solve did not roll back values and history");

    item.expected = 8'h5a;
    if (!item.randomize()) $fatal(1, "nested solve after rollback failed");
    if (leaf.value !== 8'h5a || leaf.cycle === first_cycle
        || leaf.pre_calls != 3 || leaf.post_calls != 2)
      $fatal(1, "nested alias or randc history did not resume");
    $display("PASSED");
  end
endmodule
