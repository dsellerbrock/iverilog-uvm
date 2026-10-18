// IEEE 1800-2017/2023 18.4 and 18.5: selected elements of rand arrays in a
// rand unpacked-struct member participate in the containing class solve.
typedef struct {
  rand bit [7:0] values[][];
} nested_constraint_record_t;

class nested_constraint_item;
  rand nested_constraint_record_t record;
  constraint leaf_values {
    record.values[0][0] == 8'hA5;
    record.values[1][0] == 8'h5A;
  }
endclass

module test;
  nested_constraint_item item;
  bit [7:0] values0[], values1[];
  initial begin
    item = new;
    item.record.values = new[2];
    item.record.values[0] = new[1];
    item.record.values[1] = new[1];
    if (!item.randomize()) $fatal(1, "nested struct array constraint failed");
    values0 = item.record.values[0];
    values1 = item.record.values[1];
    if (item.record.values.size() != 2
        || values0.size() != 1
        || values1.size() != 1
        || values0[0] != 8'hA5
        || values1[0] != 8'h5A)
      $fatal(1, "nested struct array elements violated constraints");
    $display("PASSED");
  end
endmodule
