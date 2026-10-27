typedef struct {
  rand bit [7:0] values[][];
} nested_record_t;

class nested_item;
  rand nested_record_t record;
  constraint array_values {
    foreach (record.values[i, j]) record.values[i][j] == 16 + 16 * i + j;
  }
endclass

module test;
  nested_item item;
  bit [7:0] row0[], row1[];
  initial begin
    item = new;
    item.record.values = new[2];
    item.record.values[0] = new[1];
    item.record.values[1] = new[2];
    if (!item.randomize()) $fatal(1, "nested dynamic-array foreach randomize failed");
    row0 = item.record.values[0];
    row1 = item.record.values[1];
    if (row0.size() != 1 || row1.size() != 2
        || row0[0] != 8'd16 || row1[0] != 8'd32 || row1[1] != 8'd33)
      $fatal(1, "nested dynamic-array foreach constraints failed");
    $display("PASSED");
  end
endmodule
