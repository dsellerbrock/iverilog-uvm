typedef struct {
  rand bit [7:0] values[][];
} nested_record_t;

class nested_item;
  rand nested_record_t record;
  constraint array_shape {
    record.values.size == 2;
    foreach (record.values[i]) record.values[i].size == i + 1;
  }
  constraint array_values {
    foreach (record.values[i, j]) record.values[i][j] == 16 + 16 * i + j;
  }
endclass

module test;
  nested_item item;
  initial begin
    item = new;
    if (!item.randomize()) $fatal(1, "nested dynamic-array randomize failed");
    if (item.record.values.size != 2
        || item.record.values[0].size() != 1
        || item.record.values[1].size() != 2
        || item.record.values[0][0] != 8'd16
        || item.record.values[1][0] != 8'd32
        || item.record.values[1][1] != 8'd33)
      $fatal(1, "nested dynamic-array size/foreach constraints failed");
    $display("PASSED");
  end
endmodule
