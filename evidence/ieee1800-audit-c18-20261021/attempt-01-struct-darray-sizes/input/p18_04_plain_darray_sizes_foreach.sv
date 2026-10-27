class plain_nested_item;
  rand bit [7:0] values[][];
  constraint array_shape {
    values.size == 2;
    foreach (values[i]) values[i].size == i + 1;
  }
  constraint array_values {
    foreach (values[i, j]) values[i][j] == 16 + 16 * i + j;
  }
endclass

module test;
  plain_nested_item item;
  initial begin
    item = new;
    if (!item.randomize()) $fatal(1, "plain nested dynamic-array randomize failed");
    if (item.values.size() != 2
        || item.values[0].size() != 1
        || item.values[1].size() != 2
        || item.values[0][0] != 8'd16
        || item.values[1][0] != 8'd32
        || item.values[1][1] != 8'd33)
      $fatal(1, "plain nested dynamic-array size/foreach constraints failed");
    $display("PASSED");
  end
endmodule
