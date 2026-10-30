class foreach_index_bit_select;
  rand bit [5:0] idx;
  rand bit expected;
  bit values[1:1];
  constraint selected_index { foreach (values[i]) i[idx] == expected; }
endclass

module test;
  initial begin
    foreach_index_bit_select item;
    item = new;
    if (!item.randomize() with { idx == 0; expected == 1; })
      $fatal(1, "in-range foreach index bit select failed");
    if (!item.randomize() with { idx == 32; expected == 0; })
      $fatal(1, "out-of-range foreach index bit select was not zero");
    $display("PASSED");
  end
endmodule
