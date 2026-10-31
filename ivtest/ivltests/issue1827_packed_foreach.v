class packed_foreach_order;
  bit [3:0] descending;
  bit [0:3] ascending;
  bit [1:0][3:0] multidimensional;
  rand bit [7:0] desc_value;
  rand bit [7:0] multi_value;
  rand bit [7:0] asc_value;

  constraint foreach_order {
    foreach (descending[i]) soft desc_value == i;
    foreach (multidimensional[i, j]) soft multi_value == i * 10 + j;
    foreach (ascending[i]) soft asc_value == i;
  }
endclass

module test;
  bit [3:0] proc_descending;
  bit [0:3] proc_ascending;
  int descending_trace = 0;
  int ascending_trace = 0;
  packed_foreach_order item;

  initial begin
    foreach (proc_descending[i]) descending_trace = descending_trace * 10 + i;
    foreach (proc_ascending[i]) ascending_trace = ascending_trace * 10 + i;

    item = new;
    if (!item.randomize()) $fatal(1, "packed foreach randomize failed");
    $display("%0d %0d %0d %0d %0d %0d", item.desc_value,
             item.multi_value, item.asc_value, descending_trace,
             ascending_trace, $bits(item.multidimensional));
  end
endmodule
