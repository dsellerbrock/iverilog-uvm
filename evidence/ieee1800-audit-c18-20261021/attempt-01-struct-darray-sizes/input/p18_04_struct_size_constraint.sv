typedef struct {
  rand bit [7:0] values[][];
} nested_record_t;

class nested_item;
  rand nested_record_t record;
  constraint array_shape {
    record.values.size == 2;
    foreach (record.values[i]) record.values[i].size == i + 1;
  }
endclass

module test;
  nested_item item;
  bit [7:0] row0[], row1[];
  initial begin
    item = new;
    if (!item.randomize()) $fatal(1, "nested dynamic-array size randomize failed");
    row0 = item.record.values[0];
    row1 = item.record.values[1];
    if (item.record.values.size() != 2 || row0.size() != 1 || row1.size() != 2)
      $fatal(1, "nested dynamic-array sizes violated constraints");
    $display("PASSED");
  end
endmodule
